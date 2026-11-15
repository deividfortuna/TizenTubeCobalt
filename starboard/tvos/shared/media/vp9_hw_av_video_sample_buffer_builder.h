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

#ifndef STARBOARD_TVOS_SHARED_MEDIA_VP9_HW_AV_VIDEO_SAMPLE_BUFFER_BUILDER_H_
#define STARBOARD_TVOS_SHARED_MEDIA_VP9_HW_AV_VIDEO_SAMPLE_BUFFER_BUILDER_H_

#include <optional>

#import "starboard/tvos/shared/media/compressed_av_video_sample_buffer_builder.h"

namespace starboard {

class Vp9HwAVVideoSampleBufferBuilder
    : public CompressedAVVideoSampleBufferBuilder {
 public:
  Vp9HwAVVideoSampleBufferBuilder() = default;

 protected:
  std::optional<CodecConfiguration> ParseCodecConfiguration(
      const InputBuffer& key_frame) override;
};

}  // namespace starboard

#endif  // STARBOARD_TVOS_SHARED_MEDIA_VP9_HW_AV_VIDEO_SAMPLE_BUFFER_BUILDER_H_
