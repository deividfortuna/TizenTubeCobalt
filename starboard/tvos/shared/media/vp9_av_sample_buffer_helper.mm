// Copyright 2020 The Cobalt Authors. All Rights Reserved.
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

#import "starboard/tvos/shared/media/vp9_av_sample_buffer_helper.h"

#include "starboard/common/log.h"

namespace starboard {

namespace {

void SetTransferCharacteristics(CFMutableDictionaryRef attachments,
                                const SbMediaColorMetadata& color) {
  SbMediaTransferId transfer_id = color.transfer;
  switch (transfer_id) {
    case kSbMediaTransferIdGamma22:
      CFNumberRef gamma_level;
      gamma_level = CFNumberCreate(NULL, kCFNumberFloat32Type, &kGammaLevel22);
      CFDictionarySetValue(attachments, kCVImageBufferGammaLevelKey,
                           gamma_level);
      CFRelease(gamma_level);
      CFDictionarySetValue(attachments, kCVImageBufferTransferFunctionKey,
                           kCVImageBufferTransferFunction_UseGamma);
      return;
    case kSbMediaTransferIdGamma24:
      gamma_level = CFNumberCreate(NULL, kCFNumberFloat32Type, &kGammaLevel24);
      CFDictionarySetValue(attachments, kCVImageBufferGammaLevelKey,
                           gamma_level);
      CFRelease(gamma_level);
      CFDictionarySetValue(attachments, kCVImageBufferTransferFunctionKey,
                           kCVImageBufferTransferFunction_UseGamma);
      return;
    case kSbMediaTransferIdGamma28:
      gamma_level = CFNumberCreate(NULL, kCFNumberFloat32Type, &kGammaLevel28);
      CFDictionarySetValue(attachments, kCVImageBufferGammaLevelKey,
                           gamma_level);
      CFRelease(gamma_level);
      CFDictionarySetValue(attachments, kCVImageBufferTransferFunctionKey,
                           kCVImageBufferTransferFunction_UseGamma);
      return;
    case kSbMediaTransferIdBt709:
    case kSbMediaTransferIdUnspecified:
    case kSbMediaTransferIdSmpte170M:
      CFDictionarySetValue(attachments, kCVImageBufferTransferFunctionKey,
                           kCVImageBufferTransferFunction_ITU_R_709_2);
      return;
    case kSbMediaTransferId10BitBt2020:
    case kSbMediaTransferId12BitBt2020:
      CFDictionarySetValue(attachments, kCVImageBufferTransferFunctionKey,
                           kCVImageBufferTransferFunction_ITU_R_2020);
      return;
    case kSbMediaTransferIdSmpteSt2084:
      CFDictionarySetValue(attachments, kCVImageBufferTransferFunctionKey,
                           kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ);
      return;
    case kSbMediaTransferIdAribStdB67:
      CFDictionarySetValue(attachments, kCVImageBufferTransferFunctionKey,
                           kCVImageBufferTransferFunction_ITU_R_2100_HLG);
      return;
    case kSbMediaTransferIdSmpte240M:
      CFDictionarySetValue(attachments, kCVImageBufferTransferFunctionKey,
                           kCVImageBufferTransferFunction_SMPTE_240M_1995);
      return;
    case kSbMediaTransferIdSmpteSt4281:
      CFDictionarySetValue(attachments, kCVImageBufferTransferFunctionKey,
                           kCVImageBufferTransferFunction_SMPTE_ST_428_1);
      return;
    case kSbMediaTransferIdReserved0:
    case kSbMediaTransferIdReserved:
    case kSbMediaTransferIdLinear:
    case kSbMediaTransferIdCustom:
    case kSbMediaTransferIdIec6196621:
    case kSbMediaTransferIdUnknown:
    case kSbMediaTransferIdLog:
    case kSbMediaTransferIdLogSqrt:
    case kSbMediaTransferIdIec6196624:
    case kSbMediaTransferIdBt1361Ecg:
    case kSbMediaTransferIdSmpteSt2084NonHdr:
      SB_NOTREACHED();
  }
  SB_NOTREACHED();
  CFDictionarySetValue(attachments, kCVImageBufferTransferFunctionKey,
                       kCVImageBufferTransferFunction_ITU_R_709_2);
}

void SetMatrixCoefficients(CFMutableDictionaryRef attachments,
                           const SbMediaColorMetadata& color) {
  SbMediaMatrixId matrix_id = color.matrix;
  switch (matrix_id) {
    case kSbMediaMatrixIdBt709:
    case kSbMediaMatrixIdUnspecified:
      CFDictionarySetValue(attachments, kCVImageBufferYCbCrMatrixKey,
                           kCVImageBufferYCbCrMatrix_ITU_R_709_2);
      return;
    case kSbMediaMatrixIdBt2020NonconstantLuminance:
      CFDictionarySetValue(attachments, kCVImageBufferYCbCrMatrixKey,
                           kCVImageBufferYCbCrMatrix_ITU_R_2020);
      return;
    case kSbMediaMatrixIdFcc:
    case kSbMediaMatrixIdSmpte170M:
    case kSbMediaMatrixIdBt470Bg:
      CFDictionarySetValue(attachments, kCVImageBufferYCbCrMatrixKey,
                           kCVImageBufferYCbCrMatrix_ITU_R_601_4);
      return;
    case kSbMediaMatrixIdSmpte240M:
      CFDictionarySetValue(attachments, kCVImageBufferYCbCrMatrixKey,
                           kCVImageBufferYCbCrMatrix_SMPTE_240M_1995);
      return;
    case kSbMediaMatrixIdRgb:
    case kSbMediaMatrixIdYCgCo:
    case kSbMediaMatrixIdBt2020ConstantLuminance:
    case kSbMediaMatrixIdYDzDx:
    case kSbMediaMatrixIdReserved:
    case kSbMediaMatrixIdInvalid:
      SB_NOTREACHED();
  }
  SB_NOTREACHED();
  CFDictionarySetValue(attachments, kCVImageBufferYCbCrMatrixKey,
                       kCVImageBufferYCbCrMatrix_ITU_R_709_2);
}

void SetPrimaries(CFMutableDictionaryRef attachments,
                  const SbMediaColorMetadata& color) {
  SbMediaPrimaryId primary_id = color.primaries;
  switch (primary_id) {
    case kSbMediaPrimaryIdBt709:
    case kSbMediaPrimaryIdUnspecified:
      CFDictionarySetValue(attachments, kCVImageBufferColorPrimariesKey,
                           kCVImageBufferColorPrimaries_ITU_R_709_2);
      return;
    case kSbMediaPrimaryIdBt2020:
      CFDictionarySetValue(attachments, kCVImageBufferColorPrimariesKey,
                           kCVImageBufferColorPrimaries_ITU_R_2020);
      return;
    case kSbMediaPrimaryIdSmpte170M:
    case kSbMediaPrimaryIdSmpte240M:
      CFDictionarySetValue(attachments, kCVImageBufferColorPrimariesKey,
                           kCVImageBufferColorPrimaries_SMPTE_C);
      return;
    case kSbMediaPrimaryIdBt470Bg:
      CFDictionarySetValue(attachments, kCVImageBufferColorPrimariesKey,
                           kCVImageBufferColorPrimaries_EBU_3213);
      return;
    case kSbMediaPrimaryIdSmpteSt4312:
      CFDictionarySetValue(attachments, kCVImageBufferColorPrimariesKey,
                           kCVImageBufferColorPrimaries_DCI_P3);
      return;
    case kSbMediaPrimaryIdSmpteSt4321:
      CFDictionarySetValue(attachments, kCVImageBufferColorPrimariesKey,
                           kCVImageBufferColorPrimaries_P3_D65);
      return;
    case kSbMediaPrimaryIdReserved0:
    case kSbMediaPrimaryIdReserved:
    case kSbMediaPrimaryIdFilm:
    case kSbMediaPrimaryIdBt470M:
    case kSbMediaPrimaryIdSmpteSt4281:
    case kSbMediaPrimaryIdUnknown:
    case kSbMediaPrimaryIdXyzD50:
    case kSbMediaPrimaryIdCustom:
      SB_NOTREACHED();
  }
  SB_NOTREACHED();
  CFDictionarySetValue(attachments, kCVImageBufferColorPrimariesKey,
                       kCVImageBufferColorPrimaries_ITU_R_709_2);
}

void SetContentLightLevelInfo(CFMutableDictionaryRef attachments,
                              const SbMediaColorMetadata& color) {
  LightLevelInfoSEI light_info(color);
  CFDataRef data;
  data = CFDataCreate(NULL, reinterpret_cast<UInt8*>(&light_info),
                      sizeof(light_info));
  CFDictionarySetValue(attachments, kCVImageBufferContentLightLevelInfoKey,
                       data);
  CFRelease(data);
}

void SetMasteringMetadata(CFMutableDictionaryRef attachments,
                          const SbMediaColorMetadata& color) {
  MasteringDisplayColorVolumeSEI color_volume(color.mastering_metadata);
  CFDataRef data;
  data = CFDataCreate(NULL, reinterpret_cast<UInt8*>(&color_volume),
                      sizeof(color_volume));
  CFDictionarySetValue(attachments,
                       kCVImageBufferMasteringDisplayColorVolumeKey, data);
  CFRelease(data);
}

}  // namespace

bool IsHdrVideo(const VideoStreamInfo& video_stream_info) {
  const auto& mime = video_stream_info.mime;
  const auto& primaries = video_stream_info.color_metadata.primaries;
  return mime.find("codecs=\"vp9.2") != mime.npos ||
         mime.find("codecs=\"vp09.02") != mime.npos ||
         primaries == kSbMediaPrimaryIdBt2020;
}

void SetHdrColorProperties(CFMutableDictionaryRef properties,
                           const SbMediaColorMetadata& color_metadata) {
  SetTransferCharacteristics(properties, color_metadata);
  SetMatrixCoefficients(properties, color_metadata);
  SetPrimaries(properties, color_metadata);
  SetContentLightLevelInfo(properties, color_metadata);
  SetMasteringMetadata(properties, color_metadata);
}

}  // namespace starboard
