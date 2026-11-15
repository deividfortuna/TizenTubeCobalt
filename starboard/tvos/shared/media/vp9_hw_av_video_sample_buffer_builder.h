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

#include "base/apple/scoped_cftyperef.h"
#import "starboard/tvos/shared/media/av_video_sample_buffer_builder.h"

namespace starboard {

class Vp9HwAVVideoSampleBufferBuilder : public AVVideoSampleBufferBuilder {
 public:
  Vp9HwAVVideoSampleBufferBuilder() = default;
  void Reset() override;
  void WriteInputBuffer(const scoped_refptr<InputBuffer>& input_buffer,
                        int64_t media_time_offset) override;
  void WriteEndOfStream() override {}
  size_t GetPrerollFrameCount() const override { return 16; }
  bool IsSampleAlreadyDecoded() const override { return false; }
  int64_t DecodingTimeNeededPerFrame() const override;
  size_t GetMaxNumberOfCachedFrames() const override { return 128; }

 private:
  bool EnsureFormatDescription(const InputBuffer& input_buffer);
  bool RefreshFormatDescription(const InputBuffer& key_frame);

  base::apple::ScopedCFTypeRef<CMFormatDescriptionRef> format_description_;
};

}  // namespace starboard

#endif  // STARBOARD_TVOS_SHARED_MEDIA_VP9_HW_AV_VIDEO_SAMPLE_BUFFER_BUILDER_H_
