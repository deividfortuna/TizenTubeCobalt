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

#ifndef COBALT_BROWSER_TVOS_NOW_PLAYING_NOW_PLAYING_PUBLISHER_H_
#define COBALT_BROWSER_TVOS_NOW_PLAYING_NOW_PLAYING_PUBLISHER_H_

#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "base/containers/flat_set.h"
#include "base/memory/weak_ptr.h"
#include "base/time/time.h"
#include "cobalt/browser/tvos/media_session_artwork.h"
#include "content/public/browser/web_contents_user_data.h"
#include "mojo/public/cpp/bindings/receiver.h"
#include "services/media_session/public/cpp/media_metadata.h"
#include "services/media_session/public/cpp/media_position.h"
#include "services/media_session/public/mojom/media_session.mojom.h"
#include "url/gurl.h"

class SkBitmap;

namespace cobalt {

class NowPlayingPublisher
    : public content::WebContentsUserData<NowPlayingPublisher>,
      public media_session::mojom::MediaSessionObserver {
 public:
  NowPlayingPublisher(const NowPlayingPublisher&) = delete;
  NowPlayingPublisher& operator=(const NowPlayingPublisher&) = delete;

  ~NowPlayingPublisher() override;

  void MediaSessionInfoChanged(
      media_session::mojom::MediaSessionInfoPtr session_info) override;
  void MediaSessionMetadataChanged(
      const std::optional<media_session::MediaMetadata>& metadata) override;
  void MediaSessionActionsChanged(
      const std::vector<media_session::mojom::MediaSessionAction>& actions)
      override;
  void MediaSessionImagesChanged(const MediaSessionImages& images) override;
  void MediaSessionPositionChanged(
      const std::optional<media_session::MediaPosition>& position) override;

 private:
  friend class content::WebContentsUserData<NowPlayingPublisher>;

  struct ObjCStorage;

  explicit NowPlayingPublisher(content::WebContents* web_contents);

  void ListenToRemoteCommands();
  void Perform(media_session::mojom::MediaSessionAction action,
               base::TimeDelta requested_position);
  void SeekBy(base::TimeDelta interval);
  bool CanPerform(media_session::mojom::MediaSessionAction action) const;
  void LoadArtwork(const media_session::MediaImage& image);
  void ShowArtwork(const GURL& artwork_url, const SkBitmap& bitmap);
  std::u16string Title() const;
  bool HasPlaybackToPublish() const;
  bool HasArtworkOfThisTitle() const;
  double PlaybackRate() const;
  void Publish();

  bool is_session_started_ = false;
  bool is_playing_ = false;
  std::optional<media_session::MediaMetadata> metadata_;
  std::optional<media_session::MediaPosition> position_;
  base::flat_set<media_session::mojom::MediaSessionAction> actions_;
  GURL artwork_url_;
  std::u16string artwork_title_;

  std::unique_ptr<ObjCStorage> objc_storage_;
  mojo::Receiver<media_session::mojom::MediaSessionObserver>
      media_session_observer_{this};
  base::WeakPtrFactory<NowPlayingPublisher> weak_factory_{this};

  WEB_CONTENTS_USER_DATA_KEY_DECL();
};

}  // namespace cobalt

#endif  // COBALT_BROWSER_TVOS_NOW_PLAYING_NOW_PLAYING_PUBLISHER_H_
