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

#ifndef COBALT_BROWSER_TVOS_CONTINUE_WATCHING_CONTINUE_WATCHING_ENTRY_H_
#define COBALT_BROWSER_TVOS_CONTINUE_WATCHING_CONTINUE_WATCHING_ENTRY_H_

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ContinueWatchingEntry : NSObject

@property(nonatomic, copy, readonly) NSString* videoId;
@property(nonatomic, copy, readonly) NSString* title;
@property(nonatomic, copy, readonly) NSString* channel;
@property(nonatomic, copy, readonly) NSURL* thumbnailURL;
@property(nonatomic, readonly) NSTimeInterval position;
@property(nonatomic, readonly) NSTimeInterval duration;
@property(nonatomic, readonly) double progress;
@property(nonatomic, copy, readonly) NSDictionary<NSString*, id>* propertyList;

+ (nullable instancetype)entryWithPropertyList:(id)propertyList;

- (instancetype)initWithVideoId:(NSString*)videoId
                          title:(NSString*)title
                        channel:(NSString*)channel
                   thumbnailURL:(nullable NSURL*)thumbnailURL
                       position:(NSTimeInterval)position
                       duration:(NSTimeInterval)duration
    NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END

#endif  // COBALT_BROWSER_TVOS_CONTINUE_WATCHING_CONTINUE_WATCHING_ENTRY_H_
