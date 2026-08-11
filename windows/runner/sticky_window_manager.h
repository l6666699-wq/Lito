#ifndef RUNNER_STICKY_WINDOW_MANAGER_H_
#define RUNNER_STICKY_WINDOW_MANAGER_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <map>
#include <memory>
#include <string>

class FlutterWindow;

/// Owns native sticky-note HWNDs and one Flutter engine per stable key.
///
/// The manager lives on the runner's process message loop. The primary engine
/// communicates through the `litetodo/sticky_windows` channel; secondary
/// engines use the same channel for snapshots and window controls.
class StickyWindowManager {
 public:
  explicit StickyWindowManager(const flutter::DartProject& project);
  ~StickyWindowManager();

  StickyWindowManager(const StickyWindowManager&) = delete;
  StickyWindowManager& operator=(const StickyWindowManager&) = delete;

  void HandlePrimaryMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void HandleSecondaryMethodCall(
      const std::string& key,
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void Close(const std::string& key);

 private:
  bool Open(const std::string& key, const std::string& project_id);
  void Sync(const std::string& key, const std::string& snapshot);
  void SetAlwaysOnTop(const std::string& key, bool value);
  void StartDragging(const std::string& key);
  std::string Snapshot(const std::string& key) const;

  const flutter::DartProject project_;
  std::map<std::string, std::unique_ptr<FlutterWindow>> windows_;
  std::map<std::string, std::string> snapshots_;
};

#endif  // RUNNER_STICKY_WINDOW_MANAGER_H_
