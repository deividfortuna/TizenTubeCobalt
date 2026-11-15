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

#import "starboard/tvos/shared/media/av1_hw_av_video_sample_buffer_builder.h"

#include <cstdint>
#include <memory>

#include "third_party/libgav1/src/src/obu_parser.h"

namespace starboard {

namespace {

constexpr int kAv1cBitDepthFlagsIndex = 2;
constexpr uint8_t kAv1cHighBitDepthFlag = 0x40;
constexpr uint8_t kAv1cTwelveBitFlag = 0x20;

int GetBitDepth(const uint8_t* av1c) {
  const uint8_t flags = av1c[kAv1cBitDepthFlagsIndex];
  const bool is_high_bit_depth = (flags & kAv1cHighBitDepthFlag) != 0;
  const bool is_twelve_bit = (flags & kAv1cTwelveBitFlag) != 0;
  if (!is_high_bit_depth) {
    return 8;
  }
  return is_twelve_bit ? 12 : 10;
}

}  // namespace

std::optional<CompressedAVVideoSampleBufferBuilder::CodecConfiguration>
Av1HwAVVideoSampleBufferBuilder::ParseCodecConfiguration(
    const InputBuffer& key_frame) {
  const VideoStreamInfo& stream_info = key_frame.video_stream_info();
  size_t av1c_size = 0;
  const std::unique_ptr<uint8_t[]> av1c =
      libgav1::ObuParser::GetAV1CodecConfigurationBox(
          key_frame.data(), key_frame.size(), &av1c_size);
  const bool has_configuration = av1c && !stream_info.frame_size.IsEmpty();
  if (!has_configuration) {
    return std::nullopt;
  }

  return CodecConfiguration{
      .codec_type = kCMVideoCodecType_AV1,
      .atom_name = @"av1C",
      .atom = [NSData dataWithBytes:av1c.get() length:av1c_size],
      .bit_depth = GetBitDepth(av1c.get()),
      .is_full_range = stream_info.color_metadata.range == kSbMediaRangeIdFull,
      .width = stream_info.frame_size.width,
      .height = stream_info.frame_size.height,
  };
}

}  // namespace starboard
