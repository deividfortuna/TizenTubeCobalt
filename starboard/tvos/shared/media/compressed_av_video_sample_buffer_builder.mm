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

#import "starboard/tvos/shared/media/compressed_av_video_sample_buffer_builder.h"

#include <utility>

#include "starboard/common/log.h"
#import "starboard/tvos/shared/media/vp9_av_sample_buffer_helper.h"

namespace starboard {

namespace {

constexpr int64_t kDecodingTimeNeededPerFrameUs = 5000;

}  // namespace

// static
NSDictionary* CompressedAVVideoSampleBufferBuilder::CreateFormatExtensions(
    const CodecConfiguration& configuration,
    const VideoStreamInfo& stream_info) {
  NSString* atoms_key = (__bridge NSString*)
      kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms;
  NSString* bit_depth_key =
      (__bridge NSString*)kCMFormatDescriptionExtension_BitsPerComponent;
  NSString* full_range_key =
      (__bridge NSString*)kCMFormatDescriptionExtension_FullRangeVideo;
  NSMutableDictionary* extensions = [@{
    atoms_key : @{configuration.atom_name : configuration.atom},
    bit_depth_key : @(configuration.bit_depth),
    full_range_key : @(configuration.is_full_range),
  } mutableCopy];
  if (IsHdrVideo(stream_info)) {
    SetHdrColorProperties((__bridge CFMutableDictionaryRef)extensions,
                          stream_info.color_metadata);
  }
  return extensions;
}

int64_t CompressedAVVideoSampleBufferBuilder::DecodingTimeNeededPerFrame()
    const {
  return kDecodingTimeNeededPerFrameUs;
}

void CompressedAVVideoSampleBufferBuilder::Reset() {
  SB_DCHECK(thread_checker_.CalledOnValidThread());
  AVVideoSampleBufferBuilder::Reset();
  format_description_.reset();
}

void CompressedAVVideoSampleBufferBuilder::WriteInputBuffer(
    const scoped_refptr<InputBuffer>& input_buffer,
    int64_t media_time_offset) {
  SB_DCHECK(thread_checker_.CalledOnValidThread());
  SB_DCHECK(input_buffer);
  SB_DCHECK(!error_occurred_);
  SB_DCHECK(output_cb_);

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

bool CompressedAVVideoSampleBufferBuilder::EnsureFormatDescription(
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

bool CompressedAVVideoSampleBufferBuilder::RefreshFormatDescription(
    const InputBuffer& key_frame) {
  @autoreleasepool {
    const std::optional<CodecConfiguration> configuration =
        ParseCodecConfiguration(key_frame);
    if (!configuration) {
      ReportError("Failed to parse the codec configuration of the key frame.");
      return false;
    }

    NSDictionary* extensions =
        CreateFormatExtensions(*configuration, key_frame.video_stream_info());
    base::apple::ScopedCFTypeRef<CMFormatDescriptionRef> description;
    OSStatus status = CMVideoFormatDescriptionCreate(
        kCFAllocatorDefault, configuration->codec_type, configuration->width,
        configuration->height, (__bridge CFDictionaryRef)extensions,
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
