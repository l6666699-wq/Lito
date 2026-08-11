#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/flutter_view_controller.h>

#include <memory>
#include <string>

#include "win32_window.h"

class StickyWindowManager;

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project,
                         StickyWindowManager* sticky_manager = nullptr,
                         std::string sticky_key = {});
  virtual ~FlutterWindow();

  bool IsStickyWindow() const { return !sticky_key_.empty(); }
  const std::string& sticky_key() const { return sticky_key_; }
  void SendStickySnapshot(const std::string& snapshot);
  void SendStickyMutation(const flutter::EncodableMap& mutation);

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  StickyWindowManager* sticky_manager_ = nullptr;
  std::string sticky_key_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      sticky_channel_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
