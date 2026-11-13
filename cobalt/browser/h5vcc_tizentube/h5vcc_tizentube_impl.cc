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

#include "cobalt/browser/h5vcc_tizentube/h5vcc_tizentube_impl.h"

#include <string>
#include <utility>

#include "cobalt/browser/global_features.h"
#include "cobalt/browser/h5vcc_tizentube/h5vcc_tizentube_platform.h"

namespace h5vcc_tizentube {

// static
void H5vccTizentubeImpl::Create(
    content::RenderFrameHost* render_frame_host,
    mojo::PendingReceiver<mojom::H5vccTizentube> receiver) {
  new H5vccTizentubeImpl(*render_frame_host, std::move(receiver));
}

H5vccTizentubeImpl::H5vccTizentubeImpl(
    content::RenderFrameHost& render_frame_host,
    mojo::PendingReceiver<mojom::H5vccTizentube> receiver)
    : content::DocumentService<mojom::H5vccTizentube>(render_frame_host,
                                                       std::move(receiver)) {}

void H5vccTizentubeImpl::InstallAppFromURL(
    const std::string& url,
    InstallAppFromURLCallback callback) {
  std::move(callback).Run(platform::InstallAppFromURL(url));
}

void H5vccTizentubeImpl::GetVersion(GetVersionCallback callback) {
  std::move(callback).Run(platform::GetVersion());
}

void H5vccTizentubeImpl::GetArchitecture(GetArchitectureCallback callback) {
  std::move(callback).Run(platform::GetArchitecture());
}

void H5vccTizentubeImpl::GetBrandAndModel(GetBrandAndModelCallback callback) {
  std::move(callback).Run(platform::GetBrandAndModel());
}

void H5vccTizentubeImpl::SetFrameRate(float frame_rate) {
  platform::SetFrameRate(frame_rate);
}

void H5vccTizentubeImpl::EnterPIP() {
  platform::EnterPIP();
}

void H5vccTizentubeImpl::SetUserAgent(const std::string& user_agent) {
  cobalt::GlobalFeatures::GetInstance()->SetSettings("user_agent_override",
                                                     user_agent);
}

void H5vccTizentubeImpl::HasSystemFeature(const std::string& feature_name,
                                          HasSystemFeatureCallback callback) {
  std::move(callback).Run(platform::HasSystemFeature(feature_name));
}

}  // namespace h5vcc_tizentube
