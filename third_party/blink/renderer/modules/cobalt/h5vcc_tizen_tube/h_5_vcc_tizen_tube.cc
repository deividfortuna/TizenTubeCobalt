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

#include "third_party/blink/renderer/modules/cobalt/h5vcc_tizen_tube/h_5_vcc_tizen_tube.h"

#include "third_party/blink/public/platform/browser_interface_broker_proxy.h"
#include "third_party/blink/public/platform/task_type.h"
#include "third_party/blink/renderer/core/dom/dom_exception.h"
#include "third_party/blink/renderer/core/execution_context/execution_context.h"
#include "third_party/blink/renderer/core/frame/local_dom_window.h"
#include "third_party/blink/renderer/platform/bindings/exception_state.h"
#include "third_party/blink/renderer/platform/wtf/functional.h"

namespace blink {

namespace {

constexpr char kServiceUnavailable[] =
    "Unable to connect to h5vcc_tizentube service";

}  // namespace

H5vccTizenTube::H5vccTizenTube(LocalDOMWindow& window)
    : ExecutionContextLifecycleObserver(window.GetExecutionContext()),
      service_(window.GetExecutionContext()) {}

void H5vccTizenTube::ContextDestroyed() {
  service_.reset();
}

void H5vccTizenTube::OnConnectionError() {
  service_.reset();
}

bool H5vccTizenTube::InstallAppFromURL(ScriptState* script_state,
                                       const WTF::String& url,
                                       ExceptionState& exception_state) {
  if (!BindOrThrow(exception_state)) {
    return false;
  }
  bool success = false;
  service_->InstallAppFromURL(url, &success);
  return success;
}

WTF::String H5vccTizenTube::GetVersion(ScriptState* script_state,
                                       ExceptionState& exception_state) {
  if (!BindOrThrow(exception_state)) {
    return WTF::String();
  }
  WTF::String version;
  service_->GetVersion(&version);
  return version;
}

WTF::String H5vccTizenTube::GetArchitecture(ScriptState* script_state,
                                            ExceptionState& exception_state) {
  if (!BindOrThrow(exception_state)) {
    return WTF::String();
  }
  WTF::String architecture;
  service_->GetArchitecture(&architecture);
  return architecture;
}

void H5vccTizenTube::SetFrameRate(float frame_rate) {
  if (!EnsureReceiverIsBound()) {
    return;
  }
  service_->SetFrameRate(frame_rate);
}

void H5vccTizenTube::EnterPIP() {
  if (!EnsureReceiverIsBound()) {
    return;
  }
  service_->EnterPIP();
}

bool H5vccTizenTube::SetUserAgent(ScriptState* script_state,
                                  const WTF::String& user_agent,
                                  ExceptionState& exception_state) {
  if (user_agent.empty()) {
    exception_state.ThrowTypeError("User agent cannot be empty");
    return false;
  }
  if (!BindOrThrow(exception_state)) {
    return false;
  }
  service_->SetUserAgent(user_agent);
  return true;
}

bool H5vccTizenTube::HasSystemFeature(ScriptState* script_state,
                                      const WTF::String& feature_name,
                                      ExceptionState& exception_state) {
  if (feature_name.empty()) {
    exception_state.ThrowTypeError("Feature name cannot be empty");
    return false;
  }
  if (!BindOrThrow(exception_state)) {
    return false;
  }
  bool has_feature = false;
  service_->HasSystemFeature(feature_name, &has_feature);
  return has_feature;
}

bool H5vccTizenTube::EnsureReceiverIsBound() {
  if (service_.is_bound()) {
    return true;
  }

  auto* execution_context = GetExecutionContext();
  if (!execution_context) {
    return false;
  }

  auto task_runner =
      execution_context->GetTaskRunner(TaskType::kMiscPlatformAPI);
  execution_context->GetBrowserInterfaceBroker().GetInterface(
      service_.BindNewPipeAndPassReceiver(task_runner));
  service_.set_disconnect_handler(WTF::BindOnce(
      &H5vccTizenTube::OnConnectionError, WrapWeakPersistent(this)));
  return service_.is_bound();
}

bool H5vccTizenTube::BindOrThrow(ExceptionState& exception_state) {
  if (EnsureReceiverIsBound()) {
    return true;
  }
  exception_state.ThrowDOMException(DOMExceptionCode::kNotSupportedError,
                                    kServiceUnavailable);
  return false;
}

void H5vccTizenTube::Trace(Visitor* visitor) const {
  visitor->Trace(service_);
  ScriptWrappable::Trace(visitor);
  ExecutionContextLifecycleObserver::Trace(visitor);
}

}  // namespace blink
