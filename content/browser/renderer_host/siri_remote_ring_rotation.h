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

#ifndef CONTENT_BROWSER_RENDERER_HOST_SIRI_REMOTE_RING_ROTATION_H_
#define CONTENT_BROWSER_RENDERER_HOST_SIRI_REMOTE_RING_ROTATION_H_

#include <optional>

namespace content {

class SiriRemoteRingRotation {
 public:
  int ClockwiseStepsForFingerAt(float right_of_center, float below_center);
  void LiftFinger();

  bool is_turning() const { return is_turning_; }

 private:
  std::optional<float> last_angle_;
  float pending_turn_ = 0;
  bool is_turning_ = false;
};

}  // namespace content

#endif  // CONTENT_BROWSER_RENDERER_HOST_SIRI_REMOTE_RING_ROTATION_H_
