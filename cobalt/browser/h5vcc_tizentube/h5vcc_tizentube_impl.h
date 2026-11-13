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

#ifndef COBALT_BROWSER_H5VCC_TIZENTUBE_H5VCC_TIZENTUBE_IMPL_H_
#define COBALT_BROWSER_H5VCC_TIZENTUBE_H5VCC_TIZENTUBE_IMPL_H_

#include <string>

#include "cobalt/browser/h5vcc_tizentube/public/mojom/h5vcc_tizentube.mojom.h"
#include "content/public/browser/document_service.h"
#include "mojo/public/cpp/bindings/pending_receiver.h"

namespace content {
class RenderFrameHost;
}  // namespace content

namespace h5vcc_tizentube {

class H5vccTizentubeImpl
    : public content::DocumentService<mojom::H5vccTizentube> {
 public:
  static void Create(content::RenderFrameHost* render_frame_host,
                     mojo::PendingReceiver<mojom::H5vccTizentube> receiver);

  H5vccTizentubeImpl(const H5vccTizentubeImpl&) = delete;
  H5vccTizentubeImpl& operator=(const H5vccTizentubeImpl&) = delete;

  void InstallAppFromURL(const std::string& url,
                         InstallAppFromURLCallback callback) override;
  void GetVersion(GetVersionCallback callback) override;
  void GetArchitecture(GetArchitectureCallback callback) override;
  void GetBrandAndModel(GetBrandAndModelCallback callback) override;
  void SetFrameRate(float frame_rate) override;
  void EnterPIP() override;
  void SetUserAgent(const std::string& user_agent) override;
  void HasSystemFeature(const std::string& feature_name,
                        HasSystemFeatureCallback callback) override;

 private:
  H5vccTizentubeImpl(content::RenderFrameHost& render_frame_host,
                     mojo::PendingReceiver<mojom::H5vccTizentube> receiver);
};

}  // namespace h5vcc_tizentube

#endif  // COBALT_BROWSER_H5VCC_TIZENTUBE_H5VCC_TIZENTUBE_IMPL_H_
