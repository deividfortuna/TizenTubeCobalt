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

#include "cobalt/browser/tvos/continue_watching/continue_watching_recorder.h"

#import <Foundation/Foundation.h>
#import <TVServices/TVServices.h>
#import <UIKit/UIKit.h>

#include "base/functional/bind.h"
#include "base/strings/strcat.h"
#include "base/strings/sys_string_conversions.h"
#include "base/time/time.h"
#import "cobalt/browser/tvos/continue_watching/continue_watching_entry.h"
#import "cobalt/browser/tvos/continue_watching/continue_watching_store.h"
#include "cobalt/browser/tvos/media_session_artwork.h"
#include "content/public/browser/media_session.h"
#include "content/public/browser/navigation_handle.h"
#include "content/public/browser/web_contents.h"
#include "net/base/apple/url_conversions.h"
#include "net/base/url_util.h"

namespace cobalt {

namespace {

constexpr base::TimeDelta kSaveInterval = base::Seconds(10);
constexpr base::TimeDelta kShortestPositionToResume = base::Seconds(30);
constexpr double kFinishedProgress = 0.95;
constexpr char kWatchRoute[] = "/watch";
constexpr char kVideoIdParameter[] = "v";

std::string WatchedVideoId(const GURL& page_url) {
  const GURL route(base::StrCat({"https://route", page_url.ref()}));
  std::string video_id;
  if (route.path() == kWatchRoute) {
    net::GetValueForKeyInQuery(route, kVideoIdParameter, &video_id);
  }
  return video_id;
}

}  // namespace

struct ContinueWatchingRecorder::ObjCStorage {
  id<NSObject> __strong resign_active_observer;
};

ContinueWatchingRecorder::ContinueWatchingRecorder(
    content::WebContents* web_contents)
    : content::WebContentsObserver(web_contents),
      content::WebContentsUserData<ContinueWatchingRecorder>(*web_contents),
      objc_storage_(std::make_unique<ObjCStorage>()) {
  content::MediaSession::Get(web_contents)
      ->AddObserver(media_session_observer_.BindNewPipeAndPassRemote());

  save_timer_.Start(FROM_HERE, kSaveInterval, this,
                    &ContinueWatchingRecorder::SaveProgress);

  const base::RepeatingClosure save_and_refresh = base::BindRepeating(
      &ContinueWatchingRecorder::SaveProgressAndRefreshTopShelf,
      weak_factory_.GetWeakPtr());
  objc_storage_->resign_active_observer = [NSNotificationCenter.defaultCenter
      addObserverForName:UIApplicationWillResignActiveNotification
                  object:nil
                   queue:NSOperationQueue.mainQueue
              usingBlock:^(NSNotification* notification) {
                save_and_refresh.Run();
              }];

  OpenPage(web_contents->GetLastCommittedURL());
}

ContinueWatchingRecorder::~ContinueWatchingRecorder() {
  [NSNotificationCenter.defaultCenter
      removeObserver:objc_storage_->resign_active_observer];
}

void ContinueWatchingRecorder::DidFinishNavigation(
    content::NavigationHandle* navigation_handle) {
  const bool is_new_page = navigation_handle->IsInPrimaryMainFrame() &&
                           navigation_handle->HasCommitted();
  if (is_new_page) {
    OpenPage(navigation_handle->GetURL());
  }
}

void ContinueWatchingRecorder::MediaSessionInfoChanged(
    media_session::mojom::MediaSessionInfoPtr session_info) {
  SaveProgress();
}

void ContinueWatchingRecorder::MediaSessionMetadataChanged(
    const std::optional<media_session::MediaMetadata>& metadata) {
  metadata_ = metadata;
  SaveProgress();
}

void ContinueWatchingRecorder::MediaSessionActionsChanged(
    const std::vector<media_session::mojom::MediaSessionAction>& actions) {}

void ContinueWatchingRecorder::MediaSessionImagesChanged(
    const base::flat_map<media_session::mojom::MediaSessionImageType,
                         std::vector<media_session::MediaImage>>& images) {
  const std::optional<media_session::MediaImage> artwork =
      LargestArtwork(images);
  artwork_url_ = artwork ? artwork->src : GURL();
  SaveProgress();
}

void ContinueWatchingRecorder::MediaSessionPositionChanged(
    const std::optional<media_session::MediaPosition>& position) {
  position_ = position;
  SaveProgress();
}

void ContinueWatchingRecorder::OpenPage(const GURL& page_url) {
  SaveProgress();

  const std::string video_id = WatchedVideoId(page_url);
  is_on_watch_page_ = !video_id.empty();

  const bool is_other_video = is_on_watch_page_ && video_id != video_id_;
  if (is_other_video) {
    video_id_ = video_id;
    ForgetPlayback();
  }
}

void ContinueWatchingRecorder::ForgetPlayback() {
  metadata_.reset();
  position_.reset();
  artwork_url_ = GURL();
}

bool ContinueWatchingRecorder::HasProgressToSave() const {
  const bool has_playback = is_on_watch_page_ && metadata_ && position_;
  if (!has_playback) {
    return false;
  }
  const base::TimeDelta duration = position_->duration();
  const bool has_known_duration = duration.is_positive() && !duration.is_inf();
  return has_known_duration && !metadata_->title.empty();
}

void ContinueWatchingRecorder::WriteProgress() {
  const base::TimeDelta position = position_->GetPosition();
  const base::TimeDelta duration = position_->duration();
  NSString* video_id = base::SysUTF8ToNSString(video_id_);

  const bool is_finished = position >= duration * kFinishedProgress;
  if (is_finished) {
    [ContinueWatchingStore removeEntryWithVideoId:video_id];
    return;
  }

  const bool is_worth_resuming = position >= kShortestPositionToResume;
  if (!is_worth_resuming) {
    return;
  }

  [ContinueWatchingStore
      saveEntry:[[ContinueWatchingEntry alloc]
                    initWithVideoId:video_id
                              title:base::SysUTF16ToNSString(metadata_->title)
                            channel:base::SysUTF16ToNSString(metadata_->artist)
                       thumbnailURL:net::NSURLWithGURL(artwork_url_)
                           position:position.InSecondsF()
                           duration:duration.InSecondsF()]];
}

void ContinueWatchingRecorder::SaveProgress() {
  if (HasProgressToSave()) {
    WriteProgress();
  }
}

void ContinueWatchingRecorder::SaveProgressAndRefreshTopShelf() {
  SaveProgress();
  [TVTopShelfContentProvider topShelfContentDidChange];
}

WEB_CONTENTS_USER_DATA_KEY_IMPL(ContinueWatchingRecorder);

}  // namespace cobalt
