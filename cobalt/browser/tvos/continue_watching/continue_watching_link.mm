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

#import "cobalt/browser/tvos/continue_watching/continue_watching_link.h"

namespace {

NSString* const kLinkScheme = @"dedtube";
NSString* const kLinkHost = @"watch";
NSString* const kVideoIdParameter = @"v";
NSString* const kStartTimeParameter = @"t";
NSString* const kApplicationURLKey = @"YTApplicationURL";

BOOL IsContinueWatchingLink(NSURL* link) {
  BOOL hasLinkScheme =
      [link.scheme.lowercaseString isEqualToString:kLinkScheme];
  BOOL hasLinkHost = [link.host.lowercaseString isEqualToString:kLinkHost];
  return hasLinkScheme && hasLinkHost;
}

NSArray<NSURLQueryItem*>* PlaybackParameters(NSURL* link) {
  NSArray<NSURLQueryItem*>* linkParameters =
      [NSURLComponents componentsWithURL:link resolvingAgainstBaseURL:NO]
          .queryItems;
  NSPredicate* isPlaybackParameter = [NSPredicate
      predicateWithFormat:@"name IN %@",
                          @[ kVideoIdParameter, kStartTimeParameter ]];
  return [linkParameters filteredArrayUsingPredicate:isPlaybackParameter];
}

}  // namespace

@implementation ContinueWatchingLink

+ (NSURL*)linkForEntry:(ContinueWatchingEntry*)entry {
  NSString* startTime =
      [NSString stringWithFormat:@"%ld", static_cast<long>(entry.position)];
  NSURLComponents* link = [[NSURLComponents alloc] init];
  link.scheme = kLinkScheme;
  link.host = kLinkHost;
  link.queryItems = @[
    [NSURLQueryItem queryItemWithName:kVideoIdParameter value:entry.videoId],
    [NSURLQueryItem queryItemWithName:kStartTimeParameter value:startTime],
  ];
  return link.URL;
}

+ (NSURL*)youTubeURLForLink:(NSURL*)link {
  id applicationURL =
      [NSBundle.mainBundle objectForInfoDictionaryKey:kApplicationURLKey];
  BOOL canConvert = IsContinueWatchingLink(link) &&
                    [applicationURL isKindOfClass:[NSString class]];
  if (!canConvert) {
    return nil;
  }
  NSURLComponents* youTubeURL =
      [NSURLComponents componentsWithString:applicationURL];
  youTubeURL.queryItems = PlaybackParameters(link);
  return youTubeURL.URL;
}

@end
