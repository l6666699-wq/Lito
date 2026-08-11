#include "flutter_window.h"

#include <optional>
#include <utility>

#include "flutter/generated_plugin_registrant.h"
#include "sticky_window_manager.h"

namespace {
constexpr char kStickyChannel[] = "litetodo/sticky_windows";
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project,
                             StickyWindowManager* sticky_manager,
                             std::string sticky_key)
    : project_(project),
      sticky_manager_(sticky_manager),
      sticky_key_(std::move(sticky_key)) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  sticky_channel_ = std::make_unique<
      flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), kStickyChannel,
      &flutter::StandardMethodCodec::GetInstance());
  if (sticky_manager_ != nullptr && !IsStickyWindow()) {
    sticky_channel_->SetMethodCallHandler(
        [this](const auto& call, auto result) {
          // The primary runner owns the native manager; this callback only
          // exists after the manager pointer has been wired by main.cpp.
          sticky_manager_->HandlePrimaryMethodCall(call, std::move(result));
        });
  } else if (sticky_manager_ != nullptr) {
    sticky_channel_->SetMethodCallHandler(
        [this](const auto& call, auto result) {
          sticky_manager_->HandleSecondaryMethodCall(
              sticky_key_, call, std::move(result));
        });
  }

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  sticky_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (IsStickyWindow() && message == WM_CLOSE) {
    sticky_manager_->Close(sticky_key_);
    return 0;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::SendStickySnapshot(const std::string& snapshot) {
  if (sticky_channel_ == nullptr) return;
  sticky_channel_->InvokeMethod(
      "update", std::make_unique<flutter::EncodableValue>(snapshot));
}

void FlutterWindow::SendStickyMutation(
    const flutter::EncodableMap& mutation) {
  if (sticky_channel_ == nullptr) return;
  sticky_channel_->InvokeMethod(
      "mutation",
      std::make_unique<flutter::EncodableValue>(mutation));
}
