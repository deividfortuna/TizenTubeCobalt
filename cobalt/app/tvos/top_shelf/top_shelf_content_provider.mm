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

#import <Foundation/Foundation.h>
#import <TVServices/TVServices.h>

#import "cobalt/browser/tvos/continue_watching/continue_watching_entry.h"
#import "cobalt/browser/tvos/continue_watching/continue_watching_link.h"
#import "cobalt/browser/tvos/continue_watching/continue_watching_store.h"

namespace {

TVTopShelfSectionedItem* ItemForEntry(ContinueWatchingEntry* entry) {
  NSURL* link = [ContinueWatchingLink linkForEntry:entry];
  TVTopShelfSectionedItem* item =
      [[TVTopShelfSectionedItem alloc] initWithIdentifier:entry.videoId];
  item.title = entry.title;
  item.imageShape = TVTopShelfSectionedItemImageShapeHDTV;
  item.playbackProgress = entry.progress;
  item.playAction = [[TVTopShelfAction alloc] initWithURL:link];
  item.displayAction = [[TVTopShelfAction alloc] initWithURL:link];
  [item setImageURL:entry.thumbnailURL
          forTraits:TVTopShelfItemImageTraitScreenScale1x |
                    TVTopShelfItemImageTraitScreenScale2x];
  return item;
}

}  // namespace

@interface DedTubeTopShelfContentProvider : TVTopShelfContentProvider
@end

@implementation DedTubeTopShelfContentProvider

- (void)loadTopShelfContentWithCompletionHandler:
    (void (^)(id<TVTopShelfContent> _Nullable))completionHandler {
  NSArray<ContinueWatchingEntry*>* entries = [ContinueWatchingStore entries];
  if (entries.count == 0) {
    completionHandler(nil);
    return;
  }

  NSMutableArray<TVTopShelfSectionedItem*>* items = [NSMutableArray array];
  for (ContinueWatchingEntry* entry in entries) {
    [items addObject:ItemForEntry(entry)];
  }
  TVTopShelfItemCollection* continueWatching =
      [[TVTopShelfItemCollection alloc] initWithItems:items];
  continueWatching.title = @"Continue Watching";

  completionHandler([[TVTopShelfSectionedContent alloc]
      initWithSections:@[ continueWatching ]]);
}

@end
