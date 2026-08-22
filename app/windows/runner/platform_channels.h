#ifndef RUNNER_PLATFORM_CHANNELS_H_
#define RUNNER_PLATFORM_CHANNELS_H_

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>

class PlatformChannels {
 public:
  PlatformChannels(flutter::BinaryMessenger* messenger, HWND window);
  ~PlatformChannels();

  PlatformChannels(const PlatformChannels&) = delete;
  PlatformChannels& operator=(const PlatformChannels&) = delete;

 private:
  using MethodResult = flutter::MethodResult<flutter::EncodableValue>;

  void HandleClipboardCall(const flutter::MethodCall<flutter::EncodableValue>& call,
                           std::unique_ptr<MethodResult> result);
  void HandleSettingsCall(const flutter::MethodCall<flutter::EncodableValue>& call,
                          std::unique_ptr<MethodResult> result);

  HWND window_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      clipboard_channel_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      settings_channel_;
};

#endif  // RUNNER_PLATFORM_CHANNELS_H_
