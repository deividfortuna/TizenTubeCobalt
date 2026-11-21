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

#include "content/browser/renderer_host/siri_remote_ring_rotation.h"

#include <cmath>
#include <numbers>

namespace content {

namespace {

constexpr float kFullTurn = 2 * std::numbers::pi_v<float>;
constexpr float kCenterRadius = 0.4f;
constexpr float kTurnToStart = kFullTurn / 8;
constexpr float kTurnPerStep = kFullTurn / 18;

float ShortestTurn(float from_angle, float to_angle) {
  return std::remainder(to_angle - from_angle, kFullTurn);
}

}  // namespace

int SiriRemoteRingRotation::ClockwiseStepsForFingerAt(float right_of_center,
                                                      float below_center) {
  const bool is_in_center =
      std::hypot(right_of_center, below_center) < kCenterRadius;
  if (is_in_center) {
    last_angle_.reset();
    pending_turn_ = 0;
    return 0;
  }

  const float angle = std::atan2(below_center, right_of_center);
  if (last_angle_) {
    pending_turn_ += ShortestTurn(*last_angle_, angle);
  }
  last_angle_ = angle;

  is_turning_ = is_turning_ || std::abs(pending_turn_) >= kTurnToStart;
  if (!is_turning_) {
    return 0;
  }

  const int steps = static_cast<int>(pending_turn_ / kTurnPerStep);
  pending_turn_ -= steps * kTurnPerStep;
  return steps;
}

void SiriRemoteRingRotation::LiftFinger() {
  *this = SiriRemoteRingRotation();
}

}  // namespace content
