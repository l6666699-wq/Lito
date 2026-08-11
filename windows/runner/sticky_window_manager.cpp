#include "sticky_window_manager.h"

#include <windows.h>

#include <algorithm>
#include <utility>
#include <vector>

#include "flutter_window.h"

namespace {
constexpr char kKeyField[] = "key";
constexpr char kProjectIdField[] = "projectId";
constexpr char kSnapshotField[] = "snapshot";
constexpr char kValueField[] = "value";
constexpr DWORD kStickyWindowStyle = WS_POPUP | WS_THICKFRAME | WS_MINIMIZEBOX;

const flutter::EncodableMap* AsMap(const flutter::EncodableValue* value) {
  if (value == nullptr) return nullptr;
  return std::get_if<flutter::EncodableMap>(value);
}

const flutter::EncodableValue* Find(const flutter::EncodableMap* map,
                                    const char* key) {
  if (map == nullptr) return nullptr;
  const auto found = map->find(flutter::EncodableValue(std::string(key)));
  return found == map->end() ? nullptr : &found->second;
}

std::string ReadString(const flutter::EncodableMap* map, const char* key) {
  const auto* value = Find(map, key);
  if (value == nullptr) return {};
  const auto* string = std::get_if<std::string>(value);
  return string == nullptr ? std::string{} : *string;
}

bool ReadBool(const flutter::EncodableMap* map, const char* key,
             bool fallback = false) {
  const auto* value = Find(map, key);
  if (value == nullptr) return fallback;
  const auto* boolean = std::get_if<bool>(value);
  return boolean == nullptr ? fallback : *boolean;
}

void InvalidArguments(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Error("invalid_arguments", "A sticky window key is required.");
}
}  // namespace

StickyWindowManager::StickyWindowManager(const flutter::DartProject& project)
    : project_(project) {}

StickyWindowManager::~StickyWindowManager() {
  while (!windows_.empty()) {
    auto it = windows_.begin();
    auto window = std::move(it->second);
    windows_.erase(it);
    if (window != nullptr) window->Destroy();
  }
}

void StickyWindowManager::HandlePrimaryMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto* arguments = AsMap(call.arguments());
  const auto key = ReadString(arguments, kKeyField);
  if (call.method_name() != "snapshot" && key.empty()) {
    InvalidArguments(std::move(result));
    return;
  }

  if (call.method_name() == "open") {
    const auto project_id = ReadString(arguments, kProjectIdField);
    if (!Open(key, project_id)) {
      result->Error("open_failed", "The sticky window could not be created.");
      return;
    }
    result->Success();
    return;
  }
  if (call.method_name() == "close") {
    Close(key);
    result->Success();
    return;
  }
  if (call.method_name() == "sync") {
    const auto snapshot = ReadString(arguments, kSnapshotField);
    if (snapshot.empty()) {
      result->Error("invalid_snapshot", "The workspace snapshot is empty.");
      return;
    }
    Sync(key, snapshot);
    result->Success();
    return;
  }
  if (call.method_name() == "alwaysOnTop") {
    SetAlwaysOnTop(key, ReadBool(arguments, kValueField));
    result->Success();
    return;
  }
  if (call.method_name() == "drag") {
    StartDragging(key);
    result->Success();
    return;
  }
  if (call.method_name() == "snapshot") {
    const auto snapshot = Snapshot(key);
    if (snapshot.empty()) {
      result->Success();
    } else {
      result->Success(flutter::EncodableValue(snapshot));
    }
    return;
  }
  result->NotImplemented();
}

void StickyWindowManager::HandleSecondaryMethodCall(
    const std::string& key,
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (key.empty()) {
    InvalidArguments(std::move(result));
    return;
  }
  if (call.method_name() == "snapshot") {
    const auto snapshot = Snapshot(key);
    if (snapshot.empty()) {
      result->Success();
    } else {
      result->Success(flutter::EncodableValue(snapshot));
    }
    return;
  }
  const auto* arguments = AsMap(call.arguments());
  if (call.method_name() == "close") {
    Close(key);
    result->Success();
    return;
  }
  if (call.method_name() == "alwaysOnTop") {
    SetAlwaysOnTop(key, ReadBool(arguments, kValueField));
    result->Success();
    return;
  }
  if (call.method_name() == "drag") {
    StartDragging(key);
    result->Success();
    return;
  }
  result->NotImplemented();
}

bool StickyWindowManager::Open(const std::string& key,
                               const std::string& project_id) {
  const auto existing = windows_.find(key);
  if (existing != windows_.end()) {
    existing->second->Show();
    return true;
  }

  auto project = project_;
  std::vector<std::string> arguments = {
      "--sticky-window",
      "--sticky-key=" + key,
  };
  if (!project_id.empty()) {
    arguments.push_back("--sticky-project-id=" + project_id);
  }
  project.set_dart_entrypoint_arguments(std::move(arguments));

  const auto index = static_cast<unsigned int>(windows_.size());
  auto window = std::make_unique<FlutterWindow>(project, this, key);
  const auto origin = Win32Window::Point(80 + index * 32, 80 + index * 32);
  if (!window->Create(L"LiteTodo Sticky", origin,
                      Win32Window::Size(360, 520), kStickyWindowStyle)) {
    return false;
  }
  window->SetQuitOnClose(false);
  window->Show();
  windows_.emplace(key, std::move(window));
  return true;
}

void StickyWindowManager::Close(const std::string& key) {
  const auto found = windows_.find(key);
  if (found == windows_.end()) return;
  auto window = std::move(found->second);
  windows_.erase(found);
  if (window != nullptr) window->Destroy();
}

void StickyWindowManager::Sync(const std::string& key,
                               const std::string& snapshot) {
  snapshots_[key] = snapshot;
  const auto found = windows_.find(key);
  if (found != windows_.end()) {
    found->second->SendStickySnapshot(snapshot);
  }
}

void StickyWindowManager::SetAlwaysOnTop(const std::string& key, bool value) {
  const auto found = windows_.find(key);
  if (found == windows_.end()) return;
  const auto handle = found->second->GetHandle();
  if (handle == nullptr) return;
  SetWindowPos(handle, value ? HWND_TOPMOST : HWND_NOTOPMOST, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
}

void StickyWindowManager::StartDragging(const std::string& key) {
  const auto found = windows_.find(key);
  if (found != windows_.end()) found->second->StartDragging();
}

std::string StickyWindowManager::Snapshot(const std::string& key) const {
  const auto found = snapshots_.find(key);
  return found == snapshots_.end() ? std::string{} : found->second;
}
