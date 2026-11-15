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

#import "starboard/tvos/shared/media/vp9_hw_av_video_sample_buffer_builder.h"

#include <cstdint>

namespace starboard {

namespace {

constexpr int kKeyFrameHeaderSizeInBytes = 9;
constexpr int kFrameMarkerBits = 2;
constexpr uint32_t kFrameMarker = 0b10;
constexpr uint32_t kKeyFrameType = 0;
constexpr int kShowFrameAndErrorResilientModeBits = 2;
constexpr int kFrameSyncCodeBits = 24;
constexpr uint32_t kFrameSyncCode = 0x498342;
constexpr int kColorSpaceBits = 3;
constexpr int kFrameDimensionBits = 16;
constexpr int kHighBitDepthProfile = 2;

constexpr uint8_t kVpccLevel51 = 51;
constexpr uint8_t kVpccChromaSubsampling420Colocated = 1;

constexpr int kIsoColorCodeBt709 = 1;
constexpr int kIsoColorCodeUnspecified = 2;

struct KeyFrameHeader {
  int profile = 0;
  int bit_depth = 8;
  bool is_full_range = false;
  int width = 0;
  int height = 0;
};

struct VpccAtom {
  uint8_t version = 1;
  uint8_t flags[3] = {};
  uint8_t profile = 0;
  uint8_t level = kVpccLevel51;
  uint8_t bit_depth_chroma_subsampling_and_range = 0;
  uint8_t color_primaries = kIsoColorCodeBt709;
  uint8_t transfer_characteristics = kIsoColorCodeBt709;
  uint8_t matrix_coefficients = kIsoColorCodeBt709;
  uint8_t codec_initialization_data_size[2] = {};
};
static_assert(sizeof(VpccAtom) == 12, "The vpcC atom payload must be 12 bytes");

class BitReader {
 public:
  explicit BitReader(const uint8_t* data) : data_(data) {}

  uint32_t Read(int bit_count) {
    uint32_t value = 0;
    for (int i = 0; i < bit_count; ++i) {
      const uint8_t byte = data_[position_ / 8];
      const int shift = 7 - position_ % 8;
      value = (value << 1) | ((byte >> shift) & 1);
      ++position_;
    }
    return value;
  }

  void Skip(int bit_count) { position_ += bit_count; }

 private:
  const uint8_t* const data_;
  int position_ = 0;
};

std::optional<KeyFrameHeader> ParseKeyFrameHeader(const InputBuffer& frame) {
  if (frame.size() < kKeyFrameHeaderSizeInBytes) {
    return std::nullopt;
  }

  BitReader reader(frame.data());
  KeyFrameHeader header;

  const bool has_frame_marker = reader.Read(kFrameMarkerBits) == kFrameMarker;
  const uint32_t profile_low_bit = reader.Read(1);
  const uint32_t profile_high_bit = reader.Read(1);
  header.profile = static_cast<int>(profile_high_bit << 1 | profile_low_bit);
  const bool shows_existing_frame = reader.Read(1) == 1;
  const bool is_key_frame = reader.Read(1) == kKeyFrameType;
  reader.Skip(kShowFrameAndErrorResilientModeBits);
  const bool has_sync_code = reader.Read(kFrameSyncCodeBits) == kFrameSyncCode;

  if (header.profile == kHighBitDepthProfile) {
    header.bit_depth = reader.Read(1) == 1 ? 12 : 10;
  }
  reader.Skip(kColorSpaceBits);
  header.is_full_range = reader.Read(1) == 1;
  header.width = static_cast<int>(reader.Read(kFrameDimensionBits)) + 1;
  header.height = static_cast<int>(reader.Read(kFrameDimensionBits)) + 1;

  const bool uses_420_subsampling =
      header.profile == 0 || header.profile == kHighBitDepthProfile;
  const bool is_supported_key_frame =
      has_frame_marker && uses_420_subsampling && !shows_existing_frame &&
      is_key_frame && has_sync_code;
  if (!is_supported_key_frame) {
    return std::nullopt;
  }
  return header;
}

uint8_t ToIsoColorCode(int color_id) {
  const bool is_unspecified =
      color_id <= kIsoColorCodeUnspecified || color_id > UINT8_MAX;
  if (is_unspecified) {
    return kIsoColorCodeBt709;
  }
  return static_cast<uint8_t>(color_id);
}

NSData* CreateVpccAtom(const KeyFrameHeader& header,
                       const SbMediaColorMetadata& color_metadata) {
  VpccAtom atom;
  atom.profile = static_cast<uint8_t>(header.profile);
  atom.bit_depth_chroma_subsampling_and_range = static_cast<uint8_t>(
      header.bit_depth << 4 | kVpccChromaSubsampling420Colocated << 1 |
      (header.is_full_range ? 1 : 0));
  atom.color_primaries = ToIsoColorCode(color_metadata.primaries);
  atom.transfer_characteristics = ToIsoColorCode(color_metadata.transfer);
  atom.matrix_coefficients = ToIsoColorCode(color_metadata.matrix);
  return [NSData dataWithBytes:&atom length:sizeof(atom)];
}

}  // namespace

std::optional<CompressedAVVideoSampleBufferBuilder::CodecConfiguration>
Vp9HwAVVideoSampleBufferBuilder::ParseCodecConfiguration(
    const InputBuffer& key_frame) {
  const std::optional<KeyFrameHeader> header = ParseKeyFrameHeader(key_frame);
  if (!header) {
    return std::nullopt;
  }

  return CodecConfiguration{
      .codec_type = kCMVideoCodecType_VP9,
      .atom_name = @"vpcC",
      .atom =
          CreateVpccAtom(*header, key_frame.video_stream_info().color_metadata),
      .bit_depth = header->bit_depth,
      .is_full_range = header->is_full_range,
      .width = header->width,
      .height = header->height,
  };
}

}  // namespace starboard
