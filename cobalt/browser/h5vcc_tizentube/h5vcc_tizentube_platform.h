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

#ifndef COBALT_BROWSER_H5VCC_TIZENTUBE_H5VCC_TIZENTUBE_PLATFORM_H_
#define COBALT_BROWSER_H5VCC_TIZENTUBE_H5VCC_TIZENTUBE_PLATFORM_H_

#include <string>

namespace h5vcc_tizentube {
namespace platform {

bool InstallAppFromURL(const std::string& url);
std::string GetVersion();
std::string GetArchitecture();
std::string GetBrandAndModel();
void SetFrameRate(float frame_rate);
void EnterPIP();
bool HasSystemFeature(const std::string& feature_name);

}  // namespace platform
}  // namespace h5vcc_tizentube

#endif  // COBALT_BROWSER_H5VCC_TIZENTUBE_H5VCC_TIZENTUBE_PLATFORM_H_
