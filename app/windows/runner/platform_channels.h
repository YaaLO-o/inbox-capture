#ifndef RUNNER_PLATFORM_CHANNELS_H_
#define RUNNER_PLATFORM_CHANNELS_H_

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>
#include <optional>

#include "system_tray.h"

class PlatformChannels {
 public:
  PlatformChannels(flutter::BinaryMessenger* messenger, HWND window);
  ~PlatformChannels();

  PlatformChannels(const PlatformChannels&) = delete;
  PlatformChannels& operator=(const PlatformChannels&) = delete;

  std::optional<LRESULT> HandleWindowMessage(UINT message, WPARAM wparam,
                                           LPARAM lparam);

 private:
  using MethodResult = flutter::MethodResult<flutter::EncodableValue>;

  void HandleClipboardCall(const flutter::MethodCall<flutter::EncodableValue>& call,
                           std::unique_ptr<MethodResult> result);
  void HandleSettingsCall(const flutter::MethodCall<flutter::EncodableValue>& call,
                          std::unique_ptr<MethodResult> result);

  HWND window_;
  bool standard_mode_ = false;
  bool quit_requested_ = false;
  bool dragging_ = false;
  POINT drag_cursor_{};
  RECT drag_frame_{};
  std::unique_ptr<SystemTray> tray_;
  void ShowWindow();
  void ResizeWindow(double width, double height);
  void SetWindowMode(bool standard);
  void HandleTrayAction(SystemTray::Action action);
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      clipboard_channel_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      settings_channel_;
};

#endif  // RUNNER_PLATFORM_CHANNELS_H_
