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
  AVPictureInPictureController* _controller;
  BOOL _waitingUntilPossible;
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

- (void)start {
  SB_DCHECK(NSThread.isMainThread);
  AVSampleBufferDisplayLayer* displayLayer =
      [self playingDisplayLayer] ?: _displayLayers.lastObject;
  BOOL canStart =
      !_controller && displayLayer && SBDPictureInPicture.isSupported;
  if (!canStart) {
    return;
  }
  _controller = [[AVPictureInPictureController alloc]
      initWithContentSource:[self contentSourceWithDisplayLayer:displayLayer]];
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
  if (!canStartNow) {
    return;
  }
  [self stopWaitingUntilPossible];
  [_controller startPictureInPicture];
}

- (void)endUnlessPossibleBeforeTimeout {
  AVPictureInPictureController* controller = _controller;
  RunOnMainQueueAfter(kStartTimeout, ^{
    BOOL isStillWaiting =
        self->_controller == controller && self->_waitingUntilPossible;
    if (isStillWaiting) {
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

- (void)pictureInPictureControllerDidStartPictureInPicture:
    (AVPictureInPictureController*)pictureInPictureController {
  [self stopUnlessSourceDisplayLayerIsReplaced];
}

- (void)pictureInPictureController:
            (AVPictureInPictureController*)pictureInPictureController
    failedToStartPictureInPictureWithError:(NSError*)error {
  SB_LOG(ERROR) << "Picture in Picture did not start: "
                << error.localizedDescription.UTF8String;
  [self end];
}

- (void)pictureInPictureControllerDidStopPictureInPicture:
    (AVPictureInPictureController*)pictureInPictureController {
  [self end];
}

- (void)pictureInPictureController:
            (AVPictureInPictureController*)pictureInPictureController
    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:
        (void (^)(BOOL restored))completionHandler {
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
