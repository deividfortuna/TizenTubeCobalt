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

#import "cobalt/browser/tvos/continue_watching/continue_watching_store.h"

namespace {

NSString* const kEntriesKey = @"ContinueWatchingEntries";
const NSUInteger kMaximumEntryCount = 10;

NSUserDefaults* SharedDefaults() {
  return
      [[NSUserDefaults alloc] initWithSuiteName:@CONTINUE_WATCHING_APP_GROUP];
}

NSMutableArray<ContinueWatchingEntry*>* EntriesWithoutVideoId(
    NSString* videoId) {
  NSMutableArray<ContinueWatchingEntry*>* entries =
      [[ContinueWatchingStore entries] mutableCopy];
  NSIndexSet* sameVideo =
      [entries indexesOfObjectsPassingTest:^BOOL(ContinueWatchingEntry* entry,
                                                 NSUInteger index, BOOL* stop) {
        return [entry.videoId isEqualToString:videoId];
      }];
  [entries removeObjectsAtIndexes:sameVideo];
  return entries;
}

void WriteEntries(NSArray<ContinueWatchingEntry*>* entries) {
  [SharedDefaults() setObject:[entries valueForKey:@"propertyList"]
                       forKey:kEntriesKey];
}

}  // namespace

@implementation ContinueWatchingStore

+ (NSArray<ContinueWatchingEntry*>*)entries {
  NSMutableArray<ContinueWatchingEntry*>* entries = [NSMutableArray array];
  for (id propertyList in [SharedDefaults() arrayForKey:kEntriesKey]) {
    ContinueWatchingEntry* entry =
        [ContinueWatchingEntry entryWithPropertyList:propertyList];
    if (entry) {
      [entries addObject:entry];
    }
  }
  return entries;
}

+ (void)saveEntry:(ContinueWatchingEntry*)entry {
  NSMutableArray<ContinueWatchingEntry*>* entries =
      EntriesWithoutVideoId(entry.videoId);
  [entries insertObject:entry atIndex:0];
  NSRange newest = NSMakeRange(0, MIN(entries.count, kMaximumEntryCount));
  WriteEntries([entries subarrayWithRange:newest]);
}

+ (void)removeEntryWithVideoId:(NSString*)videoId {
  WriteEntries(EntriesWithoutVideoId(videoId));
}

@end
