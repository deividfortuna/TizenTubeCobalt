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
#include <optional>
#include <utility>

#include "starboard/common/log.h"
#import "starboard/tvos/shared/media/vp9_av_sample_buffer_helper.h"

namespace starboard {

namespace {

constexpr int64_t kDecodingTimeNeededPerFrameUs = 5000;

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

NSDictionary* CreateFormatExtensions(const KeyFrameHeader& header,
                                     const VideoStreamInfo& stream_info) {
  const SbMediaColorMetadata& color_metadata = stream_info.color_metadata;
  NSString* atoms_key = (__bridge NSString*)
      kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms;
  NSString* bit_depth_key =
      (__bridge NSString*)kCMFormatDescriptionExtension_BitsPerComponent;
  NSString* full_range_key =
      (__bridge NSString*)kCMFormatDescriptionExtension_FullRangeVideo;
  NSMutableDictionary* extensions = [@{
    atoms_key : @{@"vpcC" : CreateVpccAtom(header, color_metadata)},
    bit_depth_key : @(header.bit_depth),
    full_range_key : @(header.is_full_range),
  } mutableCopy];
  if (IsHdrVideo(stream_info)) {
    SetHdrColorProperties((__bridge CFMutableDictionaryRef)extensions,
                          color_metadata);
  }
  return extensions;
}

}  // namespace

int64_t Vp9HwAVVideoSampleBufferBuilder::DecodingTimeNeededPerFrame() const {
  return kDecodingTimeNeededPerFrameUs;
}

void Vp9HwAVVideoSampleBufferBuilder::Reset() {
  SB_DCHECK(thread_checker_.CalledOnValidThread());
  AVVideoSampleBufferBuilder::Reset();
  format_description_.reset();
}

void Vp9HwAVVideoSampleBufferBuilder::WriteInputBuffer(
    const scoped_refptr<InputBuffer>& input_buffer,
    int64_t media_time_offset) {
  SB_DCHECK(thread_checker_.CalledOnValidThread());
  SB_DCHECK(input_buffer);
  SB_DCHECK(!error_occurred_);
  SB_DCHECK(output_cb_);
  SB_DCHECK(input_buffer->video_stream_info().codec == kSbMediaVideoCodecVp9);

  if (!EnsureFormatDescription(*input_buffer)) {
    return;
  }

  size_t data_size = input_buffer->size();
  base::apple::ScopedCFTypeRef<CMBlockBufferRef> block;
  OSStatus status = CMBlockBufferCreateWithMemoryBlock(
      kCFAllocatorDefault, nullptr, data_size, kCFAllocatorDefault, nullptr, 0,
      data_size, kCMBlockBufferAssureMemoryNowFlag, block.InitializeInto());
  if (status != 0) {
    ReportOSError("BlockBufferCreate", status);
    return;
  }

  status = CMBlockBufferReplaceDataBytes(input_buffer->data(), block.get(), 0,
                                         data_size);
  if (status != 0) {
    ReportOSError("BlockBufferReplaceDataBytes", status);
    return;
  }

  CMSampleTimingInfo timing_info = {
      .duration = kCMTimeInvalid,
      .presentationTimeStamp =
          CMTimeMake(input_buffer->timestamp() + media_time_offset, 1000000),
      .decodeTimeStamp = kCMTimeInvalid,
  };

  CMSampleBufferRef cm_sample_buffer;
  status = CMSampleBufferCreateReady(
      kCFAllocatorDefault, block.get(), format_description_.get(), 1, 1,
      &timing_info, 1, &data_size, &cm_sample_buffer);
  if (status != 0) {
    ReportOSError("SampleBufferCreate", status);
    return;
  }

  scoped_refptr<AVSampleBuffer> sample_buffer(
      new AVSampleBuffer(cm_sample_buffer, input_buffer));
  output_cb_(sample_buffer);
}

bool Vp9HwAVVideoSampleBufferBuilder::EnsureFormatDescription(
    const InputBuffer& input_buffer) {
  if (input_buffer.video_sample_info().is_key_frame) {
    return RefreshFormatDescription(input_buffer);
  }
  if (!format_description_) {
    ReportError("The first frame should be key frame.");
    return false;
  }
  return true;
}

bool Vp9HwAVVideoSampleBufferBuilder::RefreshFormatDescription(
    const InputBuffer& key_frame) {
  const std::optional<KeyFrameHeader> header = ParseKeyFrameHeader(key_frame);
  if (!header) {
    ReportError("Failed to parse the VP9 key frame header.");
    return false;
  }

  @autoreleasepool {
    NSDictionary* extensions =
        CreateFormatExtensions(*header, key_frame.video_stream_info());
    base::apple::ScopedCFTypeRef<CMFormatDescriptionRef> description;
    OSStatus status = CMVideoFormatDescriptionCreate(
        kCFAllocatorDefault, kCMVideoCodecType_VP9, header->width,
        header->height, (__bridge CFDictionaryRef)extensions,
        description.InitializeInto());
    if (status != 0) {
      ReportOSError("FormatDescriptionCreate", status);
      return false;
    }

    const bool is_same_format =
        format_description_ &&
        CMFormatDescriptionEqual(description.get(), format_description_.get());
    if (!is_same_format) {
      format_description_ = std::move(description);
    }
  }
  return true;
}

}  // namespace starboard
