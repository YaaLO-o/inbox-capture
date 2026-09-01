#include <windows.h>
#include <shellapi.h>
#include <shlobj_core.h>
#include <flutter/binary_messenger.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <cstring>
#include <iostream>
#include <map>
#include <string>
#include <vector>

#include "platform_channels.h"
#include "win32_window.h"

using Value = flutter::EncodableValue;
using Map = flutter::EncodableMap;
constexpr char kSettings[] = "com.inbox.app/settings";
constexpr char kClipboard[] = "com.inbox.app/clipboard";
int failures = 0;

void Check(bool ok, const char* name) {
  std::cout << (ok ? "PASS " : "FAIL ") << name << std::endl;
  if (!ok) ++failures;
}

struct Response {
  bool success = false;
  Value value;
  std::string error;
};

// Fake only the Flutter transport; exercise real Win32 clipboard/settings/windows.
class Messenger : public flutter::BinaryMessenger {
 public:
  void Send(const std::string&, const uint8_t*, size_t,
            flutter::BinaryReply reply) const override {
    if (reply) {
      auto data = flutter::StandardMethodCodec::GetInstance().EncodeSuccessEnvelope();
      reply(data->data(), data->size());
    }
  }
  void SetMessageHandler(const std::string& channel,
                         flutter::BinaryMessageHandler handler) override {
    handlers_[channel] = std::move(handler);
  }
  Response Call(const char* channel, const char* method, Value args = Value()) {
    const auto& codec = flutter::StandardMethodCodec::GetInstance();
    const auto data = codec.EncodeMethodCall(
        flutter::MethodCall<Value>(method, std::make_unique<Value>(args)));
    Response response;
    flutter::MethodResultFunctions<Value> result(
        [&](const Value* value) {
          response.success = true;
          if (value) response.value = *value;
        },
        [&](const std::string& code, const std::string&, const Value*) {
          response.error = code;
        }, [&] { response.error = "NOT_IMPLEMENTED"; });
    handlers_.at(channel)(data->data(), data->size(),
        [&](const uint8_t* reply, size_t size) {
          if (size == 0) result.NotImplemented();
          else codec.DecodeAndProcessResponseEnvelope(reply, size, &result);
        });
    return response;
  }
 private:
  std::map<std::string, flutter::BinaryMessageHandler> handlers_;
};

void PutBytes(UINT format, const void* bytes, size_t size) {
  HGLOBAL data = GlobalAlloc(GMEM_MOVEABLE, size);
  void* destination = GlobalLock(data);
  if (!destination) { Check(false, "allocate clipboard fixture"); return; }
  memcpy(destination, bytes, size);
  GlobalUnlock(data);
  if (!SetClipboardData(format, data)) {
    GlobalFree(data);
    Check(false, "publish clipboard fixture");
  }
}

// Preserve formats used by this app without logging clipboard contents.
class ClipboardSnapshot {
 public:
  explicit ClipboardSnapshot(HWND window) : window_(window) {
    if (!OpenClipboard(window_)) return;
    const UINT formats[] = {CF_UNICODETEXT, CF_HDROP, CF_DIB, CF_DIBV5,
      RegisterClipboardFormatW(L"PNG"), RegisterClipboardFormatW(L"image/png"),
      RegisterClipboardFormatW(L"JFIF"), RegisterClipboardFormatW(L"image/jpeg")};
    for (const UINT format : formats) {
      const HANDLE data = GetClipboardData(format);
      const SIZE_T size = data ? GlobalSize(data) : 0;
      const auto* bytes = size ? static_cast<const uint8_t*>(GlobalLock(data)) : nullptr;
      if (bytes) {
        saved_[format] = std::vector<uint8_t>(bytes, bytes + size);
        GlobalUnlock(data);
      }
    }
    CloseClipboard();
  }
  ~ClipboardSnapshot() {
    if (!OpenClipboard(window_)) return;
    EmptyClipboard();
    for (const auto& entry : saved_)
      PutBytes(entry.first, entry.second.data(), entry.second.size());
    CloseClipboard();
  }
 private:
  HWND window_;
  std::map<UINT, std::vector<uint8_t>> saved_;
};

int RunUpdaterHarness(const std::string& archive) {
  CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
  Win32Window window;
  if (!window.Create(L"INbox updater harness", {100, 100}, {420, 300})) {
    CoUninitialize();
    return 2;
  }
  Messenger messenger;
  PlatformChannels channels(&messenger, window.GetHandle());
  const auto response = messenger.Call(
      kSettings, "installUpdate", Map{{Value("path"), Value(archive)}});
  CoUninitialize();
  return response.success ? 0 : 3;
}

int main(int argc, char** argv) {
  if (argc == 3 && std::string(argv[1]) == "--exercise-updater") {
    return RunUpdaterHarness(argv[2]);
  }
  CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
  {
    Win32Window window;
    Check(window.Create(L"INbox native regression", {100, 100}, {420, 300}),
          "create a real native window");
    const HWND hwnd = window.GetHandle();
    ClipboardSnapshot snapshot(hwnd);
    Messenger messenger;
    PlatformChannels channels(&messenger, hwnd);

    const auto previousVault = messenger.Call(kSettings, "getVaultPath");
    const std::string testPath = "C:\\INbox-native-fixture\\中文 路径";
    Check(messenger.Call(kSettings, "setVaultPath",
          Map{{Value("path"), Value(testPath)}}).success, "persist Unicode Vault path");
    // A fresh adapter instance reads persisted state, rather than an in-memory cache.
    {
      Messenger fresh;
      PlatformChannels restored(&fresh, hwnd);
      const auto loaded = fresh.Call(kSettings, "getVaultPath");
      Check(loaded.success && loaded.value == Value(testPath), "new adapter restores Vault path");
    }
    if (std::holds_alternative<std::string>(previousVault.value)) {
      messenger.Call(kSettings, "setVaultPath", Map{{Value("path"), previousVault.value}});
    } else {
      messenger.Call(kSettings, "clearVaultPath");
    }

    Check(messenger.Call(kSettings, "getAppVersion").success, "read native app version");
    Check(messenger.Call(kSettings, "showWindow").success && IsWindowVisible(hwnd),
          "showWindow makes the native window visible");
    messenger.Call(kSettings, "setWindowMode", Map{{Value("mode"), Value("standard")}});
    Check((GetWindowLongPtr(hwnd, GWL_STYLE) & WS_CAPTION) == WS_CAPTION &&
          !(GetWindowLongPtr(hwnd, GWL_EXSTYLE) & WS_EX_TOPMOST), "standard window has caption and normal z-order");
    messenger.Call(kSettings, "setWindowMode", Map{{Value("mode"), Value("floating")}});
    Check(!(GetWindowLongPtr(hwnd, GWL_STYLE) & WS_CAPTION) &&
          (GetWindowLongPtr(hwnd, GWL_EXSTYLE) & WS_EX_TOPMOST), "floating window is borderless and topmost");
    Check(messenger.Call(kSettings, "hideWindow").success && !IsWindowVisible(hwnd),
          "hideWindow hides without destroying the window");

    OpenClipboard(hwnd);
    EmptyClipboard();
    const std::wstring unicode = L"  第一行\r\n第二行 😀 café\r\nhttps://example.com  ";
    PutBytes(CF_UNICODETEXT, unicode.c_str(), (unicode.size() + 1) * sizeof(wchar_t));
    CloseClipboard();
    auto text = messenger.Call(kClipboard, "readClipboard");
    Check(text.success && std::get<Map>(text.value)[Value("text")] ==
          Value("  第一行\r\n第二行 😀 café\r\nhttps://example.com  "), "Unicode multiline clipboard preserves original text");

    OpenClipboard(hwnd);
    EmptyClipboard();
    std::wstring longText(50000, L'中');
    PutBytes(CF_UNICODETEXT, longText.c_str(), (longText.size() + 1) * sizeof(wchar_t));
    CloseClipboard();
    text = messenger.Call(kClipboard, "readClipboard");
    const auto& longMap = std::get<Map>(text.value);
    Check(std::get<std::string>(longMap.at(Value("text"))).size() == 150000,
          "clipboard text longer than 32767 characters is not truncated");

    OpenClipboard(hwnd);
    EmptyClipboard();
    const uint8_t original[] = {137, 80, 78, 71, 13, 10, 26, 10, 99};
    PutBytes(RegisterClipboardFormatW(L"PNG"), original, sizeof(original));
    CloseClipboard();
    auto image = messenger.Call(kClipboard, "readClipboard");
    auto imageMap = std::get<Map>(image.value);
    Check(imageMap[Value("imageBytes")] == Value(std::vector<uint8_t>(std::begin(original), std::end(original))) &&
          imageMap[Value("imageExtension")] == Value("png"), "registered PNG bytes preserved without conversion");

    OpenClipboard(hwnd);
    EmptyClipboard();
    const uint32_t pixels[] = {0x00FF0000, 0x0000FF00, 0x000000FF, 0x00FFFFFF};
    SetClipboardData(CF_BITMAP, CreateBitmap(2, 2, 1, 32, pixels));
    CloseClipboard();
    image = messenger.Call(kClipboard, "readClipboard");
    imageMap = std::get<Map>(image.value);
    const auto* png = std::get_if<std::vector<uint8_t>>(&imageMap[Value("imageBytes")]);
    Check(png && png->size() > 8 && std::equal(png->begin(), png->begin() + 8, original),
          "Windows bitmap falls back to a PNG stream");

    OpenClipboard(hwnd);
    EmptyClipboard();
    const wchar_t fileList[] = L"C:\\独立测试\\图片.png\0C:\\独立测试\\文档.txt\0";
    std::vector<uint8_t> dropBytes(sizeof(DROPFILES) + sizeof(fileList));
    DROPFILES header{};
    header.pFiles = sizeof(DROPFILES);
    header.fWide = TRUE;
    memcpy(dropBytes.data(), &header, sizeof(header));
    memcpy(dropBytes.data() + sizeof(header), fileList, sizeof(fileList));
    PutBytes(CF_HDROP, dropBytes.data(), dropBytes.size());
    PutBytes(RegisterClipboardFormatW(L"PNG"), original, sizeof(original));
    CloseClipboard();
    const auto files = std::get<Map>(messenger.Call(kClipboard, "readClipboard").value);
    Check(files.at(Value("files")) == Value(flutter::EncodableList{
      Value("C:\\独立测试\\图片.png"), Value("C:\\独立测试\\文档.txt")}) &&
      files.find(Value("imageBytes")) == files.end(), "Explorer paths take priority over duplicate image data");

    OpenClipboard(hwnd);
    EmptyClipboard();
    CloseClipboard();
    const auto empty = messenger.Call(kClipboard, "readClipboard");
    Check(empty.success && std::get<Map>(empty.value).empty(), "empty clipboard returns no content");
  }
  CoUninitialize();
  std::cout << "Native failures: " << failures << std::endl;
  return failures == 0 ? 0 : 1;
}
