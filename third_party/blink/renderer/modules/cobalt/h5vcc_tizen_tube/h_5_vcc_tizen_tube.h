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

#ifndef THIRD_PARTY_BLINK_RENDERER_MODULES_COBALT_H5VCC_TIZENTUBE_H_5_VCC_TIZENTUBE_H_
#define THIRD_PARTY_BLINK_RENDERER_MODULES_COBALT_H5VCC_TIZENTUBE_H_5_VCC_TIZENTUBE_H_

#include "cobalt/browser/h5vcc_tizentube/public/mojom/h5vcc_tizentube.mojom-blink.h"
#include "third_party/blink/renderer/core/execution_context/execution_context_lifecycle_observer.h"
#include "third_party/blink/renderer/modules/modules_export.h"
#include "third_party/blink/renderer/platform/bindings/script_wrappable.h"
#include "third_party/blink/renderer/platform/mojo/heap_mojo_remote.h"
#include "third_party/blink/renderer/platform/wtf/text/wtf_string.h"

namespace blink {

class ExceptionState;
class LocalDOMWindow;
class ScriptState;

class MODULES_EXPORT H5vccTizenTube final
    : public ScriptWrappable,
      public ExecutionContextLifecycleObserver {
  DEFINE_WRAPPERTYPEINFO();

 public:
  explicit H5vccTizenTube(LocalDOMWindow&);

  void ContextDestroyed() override;

  bool InstallAppFromURL(ScriptState* script_state,
                         const WTF::String& url,
                         ExceptionState& exception_state);
  WTF::String GetVersion(ScriptState* script_state,
                         ExceptionState& exception_state);
  WTF::String GetArchitecture(ScriptState* script_state,
                              ExceptionState& exception_state);
  void SetFrameRate(float frame_rate);
  void EnterPIP();
  bool SetUserAgent(ScriptState* script_state,
                    const WTF::String& user_agent,
                    ExceptionState& exception_state);
  bool HasSystemFeature(ScriptState* script_state,
                        const WTF::String& feature_name,
                        ExceptionState& exception_state);

  void Trace(Visitor*) const override;

 private:
  bool EnsureReceiverIsBound();
  bool BindOrThrow(ExceptionState& exception_state);
  void OnConnectionError();

  HeapMojoRemote<h5vcc_tizentube::mojom::blink::H5vccTizentube> service_;
};

}  // namespace blink

#endif  // THIRD_PARTY_BLINK_RENDERER_MODULES_COBALT_H5VCC_TIZENTUBE_H_5_VCC_TIZENTUBE_H_
