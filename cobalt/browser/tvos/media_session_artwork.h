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

#ifndef COBALT_BROWSER_TVOS_MEDIA_SESSION_ARTWORK_H_
#define COBALT_BROWSER_TVOS_MEDIA_SESSION_ARTWORK_H_

#include <optional>
#include <vector>

#include "base/containers/flat_map.h"
#include "services/media_session/public/cpp/media_image.h"
#include "services/media_session/public/mojom/media_session.mojom.h"

namespace cobalt {

using MediaSessionImages =
    base::flat_map<media_session::mojom::MediaSessionImageType,
                   std::vector<media_session::MediaImage>>;

std::optional<media_session::MediaImage> LargestArtwork(
    const MediaSessionImages& images);

}  // namespace cobalt

#endif  // COBALT_BROWSER_TVOS_MEDIA_SESSION_ARTWORK_H_
