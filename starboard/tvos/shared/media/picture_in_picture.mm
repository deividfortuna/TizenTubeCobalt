// Copyright 2026 Reis Can (reisxd). All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "starboard/tvos/shared/media/picture_in_picture.h"

#import <AVKit/AVKit.h>
#import <UIKit/UIKit.h>

#include "starboard/common/log.h"
#import "starboard/tvos/shared/media/pip_spike_log.h"

namespace {

NSString* const kPossibleKeyPath = @"pictureInPicturePossible";
const NSTimeInterval kStartTimeout = 5;
const NSTimeInterval kReplacementDisplayLayerTimeout = 15;

bool IsPlaying(AVSampleBufferDisplayLayer* display_layer) {
  CMTimebaseRef timebase = display_layer.timebase;
  return timebase && CMTimebaseGetEffectiveRate(timebase) != 0;
}

bool IsApplicationActive() {
  return UIApplication.sharedApplication.applicationState ==
         UIApplicationStateActive;
}

void RunOnMainQueueAfter(NSTimeInterval delay, dispatch_block_t block) {
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                               static_cast<int64_t>(delay * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), block);
}

}  // namespace

@interface SBDPictureInPicture () <
    AVPictureInPictureControllerDelegate,
    AVPictureInPictureSampleBufferPlaybackDelegate>
@end

@implementation SBDPictureInPicture {
  NSMutableArray<AVSampleBufferDisplayLayer*>* _displayLayers;
  NSMutableArray<AVPlayerLayer*>* _playerLayers;
  AVPictureInPictureController* _controller;
  NSTimer* _statusTimer;
  BOOL _waitingUntilPossible;
  NSInteger _readyChecksLeft;
  AVPlayer* _detachedPlayer;
  AVPlayerLayer* _detachedLayer;
  UIView* _detachedView;
  BOOL _startsDetached;
  BOOL _restoreRequested;
}

+ (SBDPictureInPicture*)sharedInstance {
  static SBDPictureInPicture* instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[self alloc] init];
  });
  return instance;
}

+ (BOOL)isSupported {
  return AVPictureInPictureController.isPictureInPictureSupported;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _displayLayers = [[NSMutableArray alloc] init];
    _playerLayers = [[NSMutableArray alloc] init];
    PipSpikeLog([NSString
        stringWithFormat:@"=== process start, PiP supported %d ===",
                         SBDPictureInPicture.isSupported]);
    [NSNotificationCenter.defaultCenter
        addObserverForName:
            AVSampleBufferRenderSynchronizerRateDidChangeNotification
                    object:nil
                     queue:NSOperationQueue.mainQueue
                usingBlock:^(NSNotification* notification) {
                  [self followPlayingDisplayLayer];
                }];
  }
  return self;
}

- (BOOL)isRunning {
  return _controller != nil;
}

- (void)attachDisplayLayer:(AVSampleBufferDisplayLayer*)displayLayer {
  SB_DCHECK(NSThread.isMainThread);
  [_displayLayers addObject:displayLayer];
}

- (void)detachDisplayLayer:(AVSampleBufferDisplayLayer*)displayLayer {
  SB_DCHECK(NSThread.isMainThread);
  [_displayLayers removeObject:displayLayer];
  [self followPlayingDisplayLayer];
  [self stopUnlessSourceDisplayLayerIsReplaced];
}

- (AVPlayerLayer*)sourcePlayerLayer {
  return _controller.contentSource.playerLayer ?: _controller.playerLayer;
}

- (void)attachPlayerLayer:(AVPlayerLayer*)playerLayer {
  SB_DCHECK(NSThread.isMainThread);
  [_playerLayers addObject:playerLayer];
  AVPlayerLayer* sourcePlayerLayer = [self sourcePlayerLayer];
  BOOL shouldReplaceSource =
      _controller && sourcePlayerLayer && sourcePlayerLayer != playerLayer &&
      !_detachedLayer;
  PipSpikeLog([NSString
      stringWithFormat:@"player layer attached (%lu), replaces PiP source %d",
                       (unsigned long)_playerLayers.count,
                       shouldReplaceSource]);
  if (shouldReplaceSource) {
    _controller.contentSource =
        [[AVPictureInPictureControllerContentSource alloc]
            initWithPlayerLayer:playerLayer];
    PipSpikeLog([NSString
        stringWithFormat:@"PiP source replaced, active %d possible %d",
                         _controller.isPictureInPictureActive,
                         _controller.isPictureInPicturePossible]);
  }
}

- (void)detachPlayerLayer:(AVPlayerLayer*)playerLayer {
  SB_DCHECK(NSThread.isMainThread);
  BOOL isSource = _controller && [self sourcePlayerLayer] == playerLayer;
  [_playerLayers removeObject:playerLayer];
  PipSpikeLog([NSString
      stringWithFormat:@"player layer detached (%lu), was PiP source %d",
                       (unsigned long)_playerLayers.count, isSource]);
  if (!isSource) {
    return;
  }
  AVPictureInPictureController* controller = _controller;
  RunOnMainQueueAfter(kReplacementDisplayLayerTimeout, ^{
    BOOL isSourceStillDetached = self->_controller == controller &&
                                 [self sourcePlayerLayer] == playerLayer;
    if (isSourceStillDetached) {
      PipSpikeLog(@"no new player layer came, stop PiP");
      [self stop];
    }
  });
}

- (void)startWhenPlayerLayerIsReady {
  SB_DCHECK(NSThread.isMainThread);
  _startsDetached = NO;
  _readyChecksLeft = 80;
  [self startIfPlayerLayerIsReady];
}

- (void)startDetachedWhenPlayerLayerIsReady {
  SB_DCHECK(NSThread.isMainThread);
  _startsDetached = YES;
  _readyChecksLeft = 80;
  [self startIfPlayerLayerIsReady];
}

- (void)startDetachedFromPlayerLayer:(AVPlayerLayer*)pageLayer {
  AVAsset* asset = pageLayer.player.currentItem.asset;
  BOOL canDetach = !_controller && !_detachedPlayer &&
                   [asset isKindOfClass:AVURLAsset.class];
  if (!canDetach) {
    PipSpikeLog(@"detached player: cannot start");
    return;
  }
  NSURL* url = ((AVURLAsset*)asset).URL;
  CMTime position = pageLayer.player.currentTime;
  UIWindow* window = ((UIView*)pageLayer.delegate).window;
  PipSpikeLog([NSString
      stringWithFormat:@"detached player: url %@ (%lu), position %.2f, "
                       @"window %d",
                       url.scheme, (unsigned long)url.absoluteString.length,
                       CMTimeGetSeconds(position), window != nil]);
  [self.delegate pictureInPictureWillStartDetached];
  AVPlayerItem* item = [AVPlayerItem
      playerItemWithAsset:[AVURLAsset URLAssetWithURL:url options:nil]];
  _detachedPlayer = [AVPlayer playerWithPlayerItem:item];
  _detachedView = [[UIView alloc] initWithFrame:window.bounds];
  _detachedView.userInteractionEnabled = NO;
  _detachedLayer = [AVPlayerLayer playerLayerWithPlayer:_detachedPlayer];
  _detachedLayer.frame = _detachedView.bounds;
  [_detachedView.layer addSublayer:_detachedLayer];
  [window insertSubview:_detachedView atIndex:0];
  [NSNotificationCenter.defaultCenter
      addObserver:self
         selector:@selector(detachedPlayerDidReachEnd:)
             name:AVPlayerItemDidPlayToEndTimeNotification
           object:item];
  _readyChecksLeft = 150;
  [self seekDetachedPlayerWhenReadyTo:position];
}

- (void)seekDetachedPlayerWhenReadyTo:(CMTime)position {
  AVPlayer* player = _detachedPlayer;
  AVPlayerItemStatus status = player.currentItem.status;
  _readyChecksLeft--;
  BOOL hasFailed =
      status == AVPlayerItemStatusFailed || _readyChecksLeft <= 0;
  if (hasFailed) {
    PipSpikeLog([NSString
        stringWithFormat:@"detached player: not ready, error %@",
                         player.currentItem.error]);
    [self removeDetachedPlayer];
    return;
  }
  if (status != AVPlayerItemStatusReadyToPlay) {
    RunOnMainQueueAfter(0.1, ^{
      [self seekDetachedPlayerWhenReadyTo:position];
    });
    return;
  }
  PipSpikeLog(@"detached player: item is ready, seek");
  [player seekToTime:position
        toleranceBefore:kCMTimeZero
         toleranceAfter:kCMTimeZero
      completionHandler:^(BOOL finished) {
        dispatch_async(dispatch_get_main_queue(), ^{
          if (self->_detachedPlayer != player) {
            return;
          }
          PipSpikeLog([NSString
              stringWithFormat:@"detached player: seek finished %d, play",
                               finished]);
          [player play];
          self->_readyChecksLeft = 80;
          [self startIfDetachedLayerIsReady];
        });
      }];
}

- (void)startIfDetachedLayerIsReady {
  BOOL isReady =
      _detachedLayer.isReadyForDisplay && _detachedPlayer.rate > 0;
  if (isReady) {
    PipSpikeLog(@"detached player: layer is ready, start PiP");
    [self start];
    return;
  }
  _readyChecksLeft--;
  if (!_detachedPlayer || _readyChecksLeft <= 0) {
    PipSpikeLog(@"detached player: layer did not become ready");
    [self removeDetachedPlayer];
    return;
  }
  RunOnMainQueueAfter(0.1, ^{
    [self startIfDetachedLayerIsReady];
  });
}

- (void)setDetachedVolume:(float)volume {
  PipSpikeLog([NSString
      stringWithFormat:@"detached player: volume %.3f, player exists %d",
                       volume, _detachedPlayer != nil]);
  _detachedPlayer.volume = volume;
}

- (void)detachedPlayerDidReachEnd:(NSNotification*)notification {
  PipSpikeLog(@"detached player: end of the video");
  [self stop];
}

- (void)removeDetachedPlayer {
  if (!_detachedPlayer) {
    return;
  }
  PipSpikeLog(@"detached player: removed");
  [NSNotificationCenter.defaultCenter
      removeObserver:self
                name:AVPlayerItemDidPlayToEndTimeNotification
              object:_detachedPlayer.currentItem];
  [_detachedPlayer pause];
  [_detachedPlayer replaceCurrentItemWithPlayerItem:nil];
  [_detachedView removeFromSuperview];
  _detachedPlayer = nil;
  _detachedLayer = nil;
  _detachedView = nil;
}

- (void)startIfPlayerLayerIsReady {
  AVPlayerLayer* playerLayer = _playerLayers.lastObject;
  BOOL hasPosition =
      !_startsDetached ||
      CMTimeGetSeconds(playerLayer.player.currentTime) > 0.5;
  BOOL isReady = playerLayer.isReadyForDisplay &&
                 playerLayer.player.rate > 0 && hasPosition;
  if (isReady) {
    PipSpikeLog(@"player layer is ready, start PiP");
    if (_startsDetached) {
      [self startDetachedFromPlayerLayer:playerLayer];
    } else {
      [self start];
    }
    return;
  }
  _readyChecksLeft--;
  if (_readyChecksLeft <= 0) {
    PipSpikeLog(@"player layer did not become ready in 20 s");
    return;
  }
  RunOnMainQueueAfter(0.25, ^{
    [self startIfPlayerLayerIsReady];
  });
}

- (void)logStatus {
  AVPlayerLayer* playerLayer =
      _controller.playerLayer ?: _controller.contentSource.playerLayer;
  AVPlayer* player = playerLayer.player;
  AVPlayerItemAccessLogEvent* event =
      player.currentItem.accessLog.events.lastObject;
  PipSpikeLog([NSString
      stringWithFormat:
          @"status: app state %ld, PiP possible %d active %d suspended %d, "
          @"player time %.2f rate %.2f size %.0fx%.0f, indicated bitrate "
          @"%.0f, layers %lu",
          (long)UIApplication.sharedApplication.applicationState,
          _controller.isPictureInPicturePossible,
          _controller.isPictureInPictureActive,
          _controller.isPictureInPictureSuspended,
          CMTimeGetSeconds(player.currentTime), player.rate,
          player.currentItem.presentationSize.width,
          player.currentItem.presentationSize.height, event.indicatedBitrate,
          (unsigned long)_playerLayers.count]);
}

- (void)start {
  SB_DCHECK(NSThread.isMainThread);
  AVPlayerLayer* playerLayer = _detachedLayer ?: _playerLayers.lastObject;
  AVSampleBufferDisplayLayer* displayLayer =
      [self playingDisplayLayer] ?: _displayLayers.lastObject;
  BOOL hasSource = playerLayer || displayLayer;
  BOOL canStart = !_controller && hasSource && SBDPictureInPicture.isSupported;
  PipSpikeLog([NSString
      stringWithFormat:@"start: can start %d, player layers %lu, display "
                       @"layers %lu, supported %d",
                       canStart, (unsigned long)_playerLayers.count,
                       (unsigned long)_displayLayers.count,
                       SBDPictureInPicture.isSupported]);
  if (!canStart) {
    return;
  }
  if (playerLayer) {
    PipSpikeLog(_detachedLayer
                    ? @"start: source is the layer of the detached player"
                    : @"start: source is the AVPlayerLayer of the URL player");
    _controller =
        [[AVPictureInPictureController alloc] initWithPlayerLayer:playerLayer];
  } else {
    PipSpikeLog(@"start: source is the sample buffer display layer");
    _controller = [[AVPictureInPictureController alloc]
        initWithContentSource:[self
                                  contentSourceWithDisplayLayer:displayLayer]];
  }
  PipSpikeLog([NSString stringWithFormat:@"start: controller %@",
                                         _controller ? @"created" : @"nil"]);
  if (!_controller) {
    return;
  }
  _statusTimer = [NSTimer scheduledTimerWithTimeInterval:2
                                                 target:self
                                               selector:@selector(logStatus)
                                               userInfo:nil
                                                repeats:YES];
  _controller.delegate = self;
  _waitingUntilPossible = YES;
  [_controller addObserver:self
                forKeyPath:kPossibleKeyPath
                   options:0
                   context:nil];
  [self startIfPossible];
  [self endUnlessPossibleBeforeTimeout];
}

- (void)observeValueForKeyPath:(NSString*)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id>*)change
                       context:(void*)context {
  dispatch_async(dispatch_get_main_queue(), ^{
    [self startIfPossible];
  });
}

- (void)startIfPossible {
  BOOL canStartNow =
      _waitingUntilPossible && _controller.isPictureInPicturePossible;
  PipSpikeLog([NSString
      stringWithFormat:@"possible %d, waiting %d",
                       _controller.isPictureInPicturePossible,
                       _waitingUntilPossible]);
  if (!canStartNow) {
    return;
  }
  [self stopWaitingUntilPossible];
  PipSpikeLog(@"call startPictureInPicture");
  [_controller startPictureInPicture];
}

- (void)endUnlessPossibleBeforeTimeout {
  AVPictureInPictureController* controller = _controller;
  RunOnMainQueueAfter(kStartTimeout, ^{
    BOOL isStillWaiting =
        self->_controller == controller && self->_waitingUntilPossible;
    if (isStillWaiting) {
      PipSpikeLog(@"did not become possible before the timeout");
      SB_LOG(WARNING) << "Picture in Picture did not become possible.";
      [self end];
    }
  });
}

- (void)stopWaitingUntilPossible {
  if (!_waitingUntilPossible) {
    return;
  }
  _waitingUntilPossible = NO;
  [_controller removeObserver:self forKeyPath:kPossibleKeyPath];
}

- (void)stop {
  if (_waitingUntilPossible) {
    [self end];
    return;
  }
  [_controller stopPictureInPicture];
}

- (void)end {
  PipSpikeLog(@"end");
  _lastEndWasDetached = _detachedPlayer != nil;
  _lastEndWasRestore = _restoreRequested;
  _lastDetachedPosition = CMTimeGetSeconds(_detachedPlayer.currentTime);
  _restoreRequested = NO;
  [self removeDetachedPlayer];
  [_statusTimer invalidate];
  _statusTimer = nil;
  [self stopWaitingUntilPossible];
  _controller = nil;
  [self.delegate pictureInPictureDidEnd];
}

- (AVPictureInPictureControllerContentSource*)contentSourceWithDisplayLayer:
    (AVSampleBufferDisplayLayer*)displayLayer {
  return [[AVPictureInPictureControllerContentSource alloc]
      initWithSampleBufferDisplayLayer:displayLayer
                      playbackDelegate:self];
}

- (AVSampleBufferDisplayLayer*)sourceDisplayLayer {
  return _controller.contentSource.sampleBufferDisplayLayer;
}

- (AVSampleBufferDisplayLayer*)playingDisplayLayer {
  for (AVSampleBufferDisplayLayer* displayLayer in _displayLayers
           .reverseObjectEnumerator) {
    if (IsPlaying(displayLayer)) {
      return displayLayer;
    }
  }
  return nil;
}

- (void)followPlayingDisplayLayer {
  [_controller invalidatePlaybackState];
  AVSampleBufferDisplayLayer* playingDisplayLayer = [self playingDisplayLayer];
  BOOL shouldChangeSource = _controller && playingDisplayLayer &&
                            playingDisplayLayer != [self sourceDisplayLayer];
  if (shouldChangeSource) {
    _controller.contentSource =
        [self contentSourceWithDisplayLayer:playingDisplayLayer];
  }
}

- (void)stopUnlessSourceDisplayLayerIsReplaced {
  AVSampleBufferDisplayLayer* sourceDisplayLayer = [self sourceDisplayLayer];
  BOOL isSourceDetached =
      sourceDisplayLayer && ![_displayLayers containsObject:sourceDisplayLayer];
  if (!isSourceDetached) {
    return;
  }
  NSTimeInterval timeout =
      IsApplicationActive() ? 0 : kReplacementDisplayLayerTimeout;
  RunOnMainQueueAfter(timeout, ^{
    if ([self sourceDisplayLayer] == sourceDisplayLayer) {
      [self stop];
    }
  });
}

#pragma mark - AVPictureInPictureControllerDelegate

- (void)pictureInPictureControllerWillStartPictureInPicture:
    (AVPictureInPictureController*)pictureInPictureController {
  PipSpikeLog(@"delegate: will start");
}

- (void)pictureInPictureControllerDidStartPictureInPicture:
    (AVPictureInPictureController*)pictureInPictureController {
  PipSpikeLog(@"delegate: did start");
  [self stopUnlessSourceDisplayLayerIsReplaced];
}

- (void)pictureInPictureController:
            (AVPictureInPictureController*)pictureInPictureController
    failedToStartPictureInPictureWithError:(NSError*)error {
  PipSpikeLog([NSString stringWithFormat:@"delegate: failed to start: %@",
                                         error]);
  SB_LOG(ERROR) << "Picture in Picture did not start: "
                << error.localizedDescription.UTF8String;
  [self end];
}

- (void)pictureInPictureControllerWillStopPictureInPicture:
    (AVPictureInPictureController*)pictureInPictureController {
  PipSpikeLog(@"delegate: will stop");
}

- (void)pictureInPictureControllerDidStopPictureInPicture:
    (AVPictureInPictureController*)pictureInPictureController {
  PipSpikeLog(@"delegate: did stop");
  [self end];
}

- (void)pictureInPictureController:
            (AVPictureInPictureController*)pictureInPictureController
    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:
        (void (^)(BOOL restored))completionHandler {
  PipSpikeLog(@"delegate: restore user interface");
  _restoreRequested = YES;
  completionHandler(YES);
}

#pragma mark - AVPictureInPictureSampleBufferPlaybackDelegate

- (void)pictureInPictureController:
            (AVPictureInPictureController*)pictureInPictureController
                        setPlaying:(BOOL)playing {
  [self.delegate pictureInPictureSetPlaying:playing];
}

- (CMTimeRange)pictureInPictureControllerTimeRangeForPlayback:
    (AVPictureInPictureController*)pictureInPictureController {
  return CMTimeRangeMake(kCMTimeNegativeInfinity, kCMTimePositiveInfinity);
}

- (BOOL)pictureInPictureControllerIsPlaybackPaused:
    (AVPictureInPictureController*)pictureInPictureController {
  return !IsPlaying([self sourceDisplayLayer]);
}

- (void)pictureInPictureController:
            (AVPictureInPictureController*)pictureInPictureController
         didTransitionToRenderSize:(CMVideoDimensions)newRenderSize {
}

- (void)pictureInPictureController:
            (AVPictureInPictureController*)pictureInPictureController
                    skipByInterval:(CMTime)skipInterval
                 completionHandler:(void (^)(void))completionHandler {
  completionHandler();
}

@end
