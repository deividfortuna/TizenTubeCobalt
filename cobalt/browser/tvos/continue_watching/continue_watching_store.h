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

#ifndef COBALT_BROWSER_TVOS_CONTINUE_WATCHING_CONTINUE_WATCHING_STORE_H_
#define COBALT_BROWSER_TVOS_CONTINUE_WATCHING_CONTINUE_WATCHING_STORE_H_

#import <Foundation/Foundation.h>

#import "cobalt/browser/tvos/continue_watching/continue_watching_entry.h"

NS_ASSUME_NONNULL_BEGIN

@interface ContinueWatchingStore : NSObject

+ (NSArray<ContinueWatchingEntry*>*)entries;
+ (void)saveEntry:(ContinueWatchingEntry*)entry;
+ (void)removeEntryWithVideoId:(NSString*)videoId;

@end

NS_ASSUME_NONNULL_END

#endif  // COBALT_BROWSER_TVOS_CONTINUE_WATCHING_CONTINUE_WATCHING_STORE_H_
