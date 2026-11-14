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

#ifndef COBALT_BROWSER_TVOS_CONTINUE_WATCHING_CONTINUE_WATCHING_RECORDER_H_
#define COBALT_BROWSER_TVOS_CONTINUE_WATCHING_CONTINUE_WATCHING_RECORDER_H_

#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "base/containers/flat_map.h"
#include "base/memory/weak_ptr.h"
#include "base/timer/timer.h"
#include "content/public/browser/web_contents_observer.h"
#include "content/public/browser/web_contents_user_data.h"
#include "mojo/public/cpp/bindings/receiver.h"
#include "services/media_session/public/cpp/media_image.h"
#include "services/media_session/public/cpp/media_metadata.h"
#include "services/media_session/public/cpp/media_position.h"
#include "services/media_session/public/mojom/media_session.mojom.h"
#include "url/gurl.h"

namespace cobalt {

class ContinueWatchingRecorder
    : public content::WebContentsObserver,
      public content::WebContentsUserData<ContinueWatchingRecorder>,
      public media_session::mojom::MediaSessionObserver {
 public:
  ContinueWatchingRecorder(const ContinueWatchingRecorder&) = delete;
  ContinueWatchingRecorder& operator=(const ContinueWatchingRecorder&) = delete;

  ~ContinueWatchingRecorder() override;

  void DidFinishNavigation(
      content::NavigationHandle* navigation_handle) override;

  void MediaSessionInfoChanged(
      media_session::mojom::MediaSessionInfoPtr session_info) override;
  void MediaSessionMetadataChanged(
      const std::optional<media_session::MediaMetadata>& metadata) override;
  void MediaSessionActionsChanged(
      const std::vector<media_session::mojom::MediaSessionAction>& actions)
      override;
  void MediaSessionImagesChanged(
      const base::flat_map<media_session::mojom::MediaSessionImageType,
                           std::vector<media_session::MediaImage>>& images)
      override;
  void MediaSessionPositionChanged(
      const std::optional<media_session::MediaPosition>& position) override;

 private:
  friend class content::WebContentsUserData<ContinueWatchingRecorder>;

  struct ObjCStorage;

  explicit ContinueWatchingRecorder(content::WebContents* web_contents);

  void OpenPage(const GURL& page_url);
  void ForgetPlayback();
  bool HasProgressToSave() const;
  void WriteProgress();
  void SaveProgress();
  void SaveProgressAndRefreshTopShelf();

  bool is_on_watch_page_ = false;
  std::string video_id_;
  std::optional<media_session::MediaMetadata> metadata_;
  std::optional<media_session::MediaPosition> position_;
  GURL artwork_url_;

  base::RepeatingTimer save_timer_;
  std::unique_ptr<ObjCStorage> objc_storage_;
  mojo::Receiver<media_session::mojom::MediaSessionObserver>
      media_session_observer_{this};
  base::WeakPtrFactory<ContinueWatchingRecorder> weak_factory_{this};

  WEB_CONTENTS_USER_DATA_KEY_DECL();
};

}  // namespace cobalt

#endif  // COBALT_BROWSER_TVOS_CONTINUE_WATCHING_CONTINUE_WATCHING_RECORDER_H_
