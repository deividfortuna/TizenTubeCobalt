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

#ifndef STARBOARD_TVOS_SHARED_MEDIA_PICTURE_IN_PICTURE_H_
#define STARBOARD_TVOS_SHARED_MEDIA_PICTURE_IN_PICTURE_H_

#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SBDPictureInPictureDelegate <NSObject>

- (void)pictureInPictureDidEnd;
- (void)pictureInPictureSetPlaying:(BOOL)playing;

@end

@interface SBDPictureInPicture : NSObject

@property(class, nonatomic, readonly) SBDPictureInPicture* sharedInstance;
@property(class, nonatomic, readonly, getter=isSupported) BOOL supported;

@property(nonatomic, weak, nullable) id<SBDPictureInPictureDelegate> delegate;
@property(nonatomic, readonly, getter=isRunning) BOOL running;

- (void)attachDisplayLayer:(AVSampleBufferDisplayLayer*)displayLayer;
- (void)detachDisplayLayer:(AVSampleBufferDisplayLayer*)displayLayer;
- (void)start;

@end

NS_ASSUME_NONNULL_END

#endif  // STARBOARD_TVOS_SHARED_MEDIA_PICTURE_IN_PICTURE_H_
