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

#include "cobalt/browser/tvos/media_session_artwork.h"

#include <algorithm>

#include "ui/gfx/geometry/size.h"

namespace cobalt {

namespace {

int LargestArea(const media_session::MediaImage& image) {
  int largest_area = 0;
  for (const gfx::Size& size : image.sizes) {
    largest_area = std::max(largest_area, size.GetArea());
  }
  return largest_area;
}

}  // namespace

std::optional<media_session::MediaImage> LargestArtwork(
    const MediaSessionImages& images) {
  const auto artwork =
      images.find(media_session::mojom::MediaSessionImageType::kArtwork);
  const bool has_artwork = artwork != images.end() && !artwork->second.empty();
  if (!has_artwork) {
    return std::nullopt;
  }
  return *std::ranges::max_element(artwork->second, {}, &LargestArea);
}

}  // namespace cobalt
