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

#import "cobalt/browser/tvos/continue_watching/continue_watching_entry.h"

namespace {

NSString* const kVideoIdKey = @"videoId";
NSString* const kTitleKey = @"title";
NSString* const kChannelKey = @"channel";
NSString* const kThumbnailKey = @"thumbnail";
NSString* const kPositionKey = @"position";
NSString* const kDurationKey = @"duration";

NSString* StringForKey(NSDictionary* propertyList, NSString* key) {
  id value = propertyList[key];
  return [value isKindOfClass:[NSString class]] ? value : nil;
}

NSTimeInterval SecondsForKey(NSDictionary* propertyList, NSString* key) {
  id value = propertyList[key];
  return [value isKindOfClass:[NSNumber class]] ? [value doubleValue] : 0;
}

NSURL* DefaultThumbnailURL(NSString* videoId) {
  NSURLComponents* components = [[NSURLComponents alloc] init];
  components.scheme = @"https";
  components.host = @"i.ytimg.com";
  components.path =
      [NSString stringWithFormat:@"/vi/%@/hqdefault.jpg", videoId];
  return components.URL;
}

}  // namespace

@implementation ContinueWatchingEntry

+ (instancetype)entryWithPropertyList:(id)propertyList {
  if (![propertyList isKindOfClass:[NSDictionary class]]) {
    return nil;
  }
  NSString* videoId = StringForKey(propertyList, kVideoIdKey);
  NSTimeInterval duration = SecondsForKey(propertyList, kDurationKey);
  BOOL isComplete = videoId.length > 0 && duration > 0;
  if (!isComplete) {
    return nil;
  }
  NSString* thumbnail = StringForKey(propertyList, kThumbnailKey);
  return [[self alloc]
      initWithVideoId:videoId
                title:StringForKey(propertyList, kTitleKey) ?: @""
              channel:StringForKey(propertyList, kChannelKey) ?: @""
         thumbnailURL:thumbnail ? [NSURL URLWithString:thumbnail] : nil
             position:SecondsForKey(propertyList, kPositionKey)
             duration:duration];
}

- (instancetype)initWithVideoId:(NSString*)videoId
                          title:(NSString*)title
                        channel:(NSString*)channel
                   thumbnailURL:(NSURL*)thumbnailURL
                       position:(NSTimeInterval)position
                       duration:(NSTimeInterval)duration {
  self = [super init];
  if (self) {
    _videoId = [videoId copy];
    _title = [title copy];
    _channel = [channel copy];
    _thumbnailURL = [thumbnailURL copy] ?: DefaultThumbnailURL(videoId);
    _position = position;
    _duration = duration;
  }
  return self;
}

- (double)progress {
  return MIN(MAX(self.position / self.duration, 0.0), 1.0);
}

- (NSDictionary<NSString*, id>*)propertyList {
  return @{
    kVideoIdKey : self.videoId,
    kTitleKey : self.title,
    kChannelKey : self.channel,
    kThumbnailKey : self.thumbnailURL.absoluteString,
    kPositionKey : @(self.position),
    kDurationKey : @(self.duration),
  };
}

@end
