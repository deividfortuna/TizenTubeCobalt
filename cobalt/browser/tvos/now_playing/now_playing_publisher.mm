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

#include "cobalt/browser/tvos/now_playing/now_playing_publisher.h"

#import <CoreGraphics/CoreGraphics.h>
#import <MediaPlayer/MediaPlayer.h>
#import <UIKit/UIKit.h>

#include <algorithm>

#include "base/apple/foundation_util.h"
#include "base/apple/scoped_cftyperef.h"
#include "base/functional/bind.h"
#include "base/notreached.h"
#include "base/strings/sys_string_conversions.h"
#include "base/task/bind_post_task.h"
#include "content/public/browser/media_session.h"
#include "content/public/browser/web_contents.h"
#include "skia/ext/skia_utils_ios.h"
#include "third_party/skia/include/core/SkBitmap.h"

namespace cobalt {

namespace {

using media_session::mojom::MediaSessionAction;
using SuspendType = media_session::mojom::MediaSession::SuspendType;

constexpr base::TimeDelta kSkipInterval = base::Seconds(10);
constexpr int kSmallestArtworkSize = 100;
constexpr int kPreferredArtworkSize = 720;
constexpr double kPausedPlaybackRate = 0;
constexpr double kNormalPlaybackRate = 1;

struct RemoteControl {
  MPRemoteCommand* __strong command;
  MediaSessionAction action;
  id __strong target;
};

std::vector<RemoteControl> RemoteControls() {
  MPRemoteCommandCenter* remote = MPRemoteCommandCenter.sharedCommandCenter;
  return {
      {remote.playCommand, MediaSessionAction::kPlay},
      {remote.pauseCommand, MediaSessionAction::kPause},
      {remote.nextTrackCommand, MediaSessionAction::kNextTrack},
      {remote.previousTrackCommand, MediaSessionAction::kPreviousTrack},
      {remote.skipForwardCommand, MediaSessionAction::kSeekForward},
      {remote.skipBackwardCommand, MediaSessionAction::kSeekBackward},
      {remote.changePlaybackPositionCommand, MediaSessionAction::kSeekTo},
  };
}

base::TimeDelta RequestedPosition(MPRemoteCommandEvent* event) {
  MPChangePlaybackPositionCommandEvent* position_change =
      base::apple::ObjCCast<MPChangePlaybackPositionCommandEvent>(event);
  return base::Seconds(position_change.positionTime);
}

NSDictionary<NSString*, id>* Description(
    const media_session::MediaMetadata& metadata) {
  return @{
    MPMediaItemPropertyTitle : base::SysUTF16ToNSString(metadata.title),
    MPMediaItemPropertyArtist : base::SysUTF16ToNSString(metadata.artist),
    MPMediaItemPropertyAlbumTitle : base::SysUTF16ToNSString(metadata.album),
    MPNowPlayingInfoPropertyMediaType : @(MPNowPlayingInfoMediaTypeVideo),
  };
}

NSDictionary<NSString*, id>* Timeline(
    const media_session::MediaPosition& position) {
  const base::TimeDelta duration = position.duration();
  if (duration.is_inf()) {
    return @{MPNowPlayingInfoPropertyIsLiveStream : @YES};
  }
  return @{
    MPMediaItemPropertyPlaybackDuration : @(duration.InSecondsF()),
    MPNowPlayingInfoPropertyElapsedPlaybackTime :
        @(position.GetPosition().InSecondsF()),
  };
}

MPMediaItemArtwork* Artwork(const SkBitmap& bitmap) {
  const base::apple::ScopedCFTypeRef<CGColorSpaceRef> color_space(
      CGColorSpaceCreateDeviceRGB());
  UIImage* image =
      skia::SkBitmapToUIImageWithColorSpace(bitmap, 1, color_space.get());
  if (!image) {
    return nil;
  }
  return [[MPMediaItemArtwork alloc] initWithBoundsSize:image.size
                                         requestHandler:^UIImage*(CGSize size) {
                                           return image;
                                         }];
}

}  // namespace

struct NowPlayingPublisher::ObjCStorage {
  std::vector<RemoteControl> remote_controls = RemoteControls();
  MPMediaItemArtwork* __strong artwork;
};

NowPlayingPublisher::NowPlayingPublisher(content::WebContents* web_contents)
    : content::WebContentsUserData<NowPlayingPublisher>(*web_contents),
      objc_storage_(std::make_unique<ObjCStorage>()) {
  ListenToRemoteCommands();
  Publish();
  content::MediaSession::Get(web_contents)
      ->AddObserver(media_session_observer_.BindNewPipeAndPassRemote());
}

NowPlayingPublisher::~NowPlayingPublisher() {
  for (const RemoteControl& control : objc_storage_->remote_controls) {
    [control.command removeTarget:control.target];
  }
  MPNowPlayingInfoCenter.defaultCenter.nowPlayingInfo = nil;
}

void NowPlayingPublisher::MediaSessionInfoChanged(
    media_session::mojom::MediaSessionInfoPtr session_info) {
  is_session_started_ =
      session_info->state !=
      media_session::mojom::MediaSessionInfo::SessionState::kInactive;
  is_playing_ = session_info->playback_state ==
                media_session::mojom::MediaPlaybackState::kPlaying;
  Publish();
}

void NowPlayingPublisher::MediaSessionMetadataChanged(
    const std::optional<media_session::MediaMetadata>& metadata) {
  metadata_ = metadata;
  Publish();
}

void NowPlayingPublisher::MediaSessionActionsChanged(
    const std::vector<MediaSessionAction>& actions) {
  actions_ = base::flat_set<MediaSessionAction>(actions);
  Publish();
}

void NowPlayingPublisher::MediaSessionImagesChanged(
    const MediaSessionImages& images) {
  const std::optional<media_session::MediaImage> artwork =
      LargestArtwork(images);
  if (!artwork) {
    return;
  }

  artwork_title_ = Title();
  const bool is_new_artwork = artwork->src != artwork_url_;
  if (is_new_artwork) {
    LoadArtwork(*artwork);
  }
  Publish();
}

void NowPlayingPublisher::MediaSessionPositionChanged(
    const std::optional<media_session::MediaPosition>& position) {
  position_ = position;
  Publish();
}

void NowPlayingPublisher::ListenToRemoteCommands() {
  MPRemoteCommandCenter* remote = MPRemoteCommandCenter.sharedCommandCenter;
  NSArray<NSNumber*>* skip_intervals = @[ @(kSkipInterval.InSecondsF()) ];
  remote.skipForwardCommand.preferredIntervals = skip_intervals;
  remote.skipBackwardCommand.preferredIntervals = skip_intervals;

  for (RemoteControl& control : objc_storage_->remote_controls) {
    const base::RepeatingCallback<void(base::TimeDelta)> perform =
        base::BindPostTaskToCurrentDefault(
            base::BindRepeating(&NowPlayingPublisher::Perform,
                                weak_factory_.GetWeakPtr(), control.action));
    control.target =
        [control.command addTargetWithHandler:^MPRemoteCommandHandlerStatus(
                             MPRemoteCommandEvent* event) {
          perform.Run(RequestedPosition(event));
          return MPRemoteCommandHandlerStatusSuccess;
        }];
  }
}

void NowPlayingPublisher::Perform(MediaSessionAction action,
                                  base::TimeDelta requested_position) {
  if (!CanPerform(action)) {
    return;
  }

  content::MediaSession* session =
      content::MediaSession::Get(&GetWebContents());
  switch (action) {
    case MediaSessionAction::kPlay:
      session->Resume(SuspendType::kUI);
      return;
    case MediaSessionAction::kPause:
      session->Suspend(SuspendType::kUI);
      return;
    case MediaSessionAction::kNextTrack:
      session->NextTrack();
      return;
    case MediaSessionAction::kPreviousTrack:
      session->PreviousTrack();
      return;
    case MediaSessionAction::kSeekForward:
      SeekBy(kSkipInterval);
      return;
    case MediaSessionAction::kSeekBackward:
      SeekBy(-kSkipInterval);
      return;
    case MediaSessionAction::kSeekTo:
      session->SeekTo(requested_position);
      return;
    default:
      NOTREACHED();
  }
}

void NowPlayingPublisher::SeekBy(base::TimeDelta interval) {
  if (!position_) {
    return;
  }
  const base::TimeDelta target =
      std::clamp(position_->GetPosition() + interval, base::TimeDelta(),
                 position_->duration());
  content::MediaSession::Get(&GetWebContents())->SeekTo(target);
}

bool NowPlayingPublisher::CanPerform(MediaSessionAction action) const {
  return HasPlaybackToPublish() && actions_.contains(action);
}

void NowPlayingPublisher::LoadArtwork(const media_session::MediaImage& image) {
  artwork_url_ = image.src;
  objc_storage_->artwork = nil;
  content::MediaSession::Get(&GetWebContents())
      ->GetMediaImageBitmap(
          image, kSmallestArtworkSize, kPreferredArtworkSize,
          base::BindOnce(&NowPlayingPublisher::ShowArtwork,
                         weak_factory_.GetWeakPtr(), image.src));
}

void NowPlayingPublisher::ShowArtwork(const GURL& artwork_url,
                                      const SkBitmap& bitmap) {
  const bool is_current_artwork = artwork_url == artwork_url_;
  if (!is_current_artwork) {
    return;
  }
  objc_storage_->artwork = Artwork(bitmap);
  Publish();
}

std::u16string NowPlayingPublisher::Title() const {
  return metadata_ ? metadata_->title : std::u16string();
}

bool NowPlayingPublisher::HasPlaybackToPublish() const {
  return is_session_started_ && !Title().empty();
}

bool NowPlayingPublisher::HasArtworkOfThisTitle() const {
  return Title() == artwork_title_;
}

double NowPlayingPublisher::PlaybackRate() const {
  if (!is_playing_) {
    return kPausedPlaybackRate;
  }
  return position_ ? position_->playback_rate() : kNormalPlaybackRate;
}

void NowPlayingPublisher::Publish() {
  for (const RemoteControl& control : objc_storage_->remote_controls) {
    control.command.enabled = CanPerform(control.action);
  }

  if (!HasPlaybackToPublish()) {
    MPNowPlayingInfoCenter.defaultCenter.nowPlayingInfo = nil;
    return;
  }

  NSMutableDictionary<NSString*, id>* info =
      [Description(*metadata_) mutableCopy];
  if (position_) {
    [info addEntriesFromDictionary:Timeline(*position_)];
  }
  info[MPNowPlayingInfoPropertyPlaybackRate] = @(PlaybackRate());
  if (HasArtworkOfThisTitle()) {
    info[MPMediaItemPropertyArtwork] = objc_storage_->artwork;
  }
  MPNowPlayingInfoCenter.defaultCenter.nowPlayingInfo = info;
}

WEB_CONTENTS_USER_DATA_KEY_IMPL(NowPlayingPublisher);

}  // namespace cobalt
