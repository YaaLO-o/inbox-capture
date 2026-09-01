#include "platform_channels.h"

#include <flutter/standard_method_codec.h>
#include <gdiplus.h>
#include <shellapi.h>
#include <shobjidl.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cwchar>
#include <limits>
#include <optional>
#include <string>
#include <utility>
#include <vector>

#include "utils.h"

namespace {

constexpr char kClipboardChannel[] = "com.inbox.app/clipboard";
constexpr char kSettingsChannel[] = "com.inbox.app/settings";
constexpr wchar_t kRegistryKey[] = L"Software\\INbox";
constexpr wchar_t kVaultValue[] = L"VaultPath";
constexpr wchar_t kDisplayMethodValue[] = L"DisplayMethod";

class ScopedClipboard {
 public:
  explicit ScopedClipboard(HWND window) : opened_(OpenClipboard(window) != FALSE) {}
  ~ScopedClipboard() {
    if (opened_) {
      CloseClipboard();
    }
  }
  bool opened() const { return opened_; }

 private:
  bool opened_;
};

std::wstring WideFromUtf8(const std::string& input) {
  if (input.empty() ||
      input.size() > static_cast<size_t>(std::numeric_limits<int>::max())) {
    return std::wstring();
  }
  const int size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                       input.data(),
                                       static_cast<int>(input.size()), nullptr, 0);
  if (size <= 0) {
    return std::wstring();
  }
  std::wstring output(static_cast<size_t>(size), L'\0');
  if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, input.data(),
                          static_cast<int>(input.size()), output.data(), size) == 0) {
    return std::wstring();
  }
  return output;
}

std::optional<std::vector<uint8_t>> ReadGlobalBytes(UINT format) {
  if (!IsClipboardFormatAvailable(format)) {
    return std::nullopt;
  }
  HANDLE handle = GetClipboardData(format);
  if (handle == nullptr) {
    return std::nullopt;
  }
  const SIZE_T size = GlobalSize(handle);
  if (size == 0) {
    return std::nullopt;
  }
  const void* data = GlobalLock(handle);
  if (data == nullptr) {
    return std::nullopt;
  }
  const auto* begin = static_cast<const uint8_t*>(data);
  std::vector<uint8_t> bytes(begin, begin + size);
  GlobalUnlock(handle);
  return bytes;
}

std::optional<std::string> ReadClipboardText() {
  if (!IsClipboardFormatAvailable(CF_UNICODETEXT)) {
    return std::nullopt;
  }
  HANDLE handle = GetClipboardData(CF_UNICODETEXT);
  if (handle == nullptr) {
    return std::nullopt;
  }
  const SIZE_T bytes = GlobalSize(handle);
  if (bytes < sizeof(wchar_t)) {
    return std::nullopt;
  }
  const auto* text = static_cast<const wchar_t*>(GlobalLock(handle));
  if (text == nullptr) {
    return std::nullopt;
  }
  const size_t capacity = bytes / sizeof(wchar_t);
  const size_t length = wcsnlen(text, capacity);
  std::string utf8 = Utf8FromUtf16(text, length);
  GlobalUnlock(handle);
  if (utf8.empty()) {
    return std::nullopt;
  }
  return utf8;
}

std::vector<std::string> ReadClipboardFiles() {
  std::vector<std::string> files;
  if (!IsClipboardFormatAvailable(CF_HDROP)) {
    return files;
  }
  const auto drop = static_cast<HDROP>(GetClipboardData(CF_HDROP));
  if (drop == nullptr) {
    return files;
  }
  const UINT count = DragQueryFileW(drop, 0xFFFFFFFF, nullptr, 0);
  for (UINT index = 0; index < count; ++index) {
    const UINT length = DragQueryFileW(drop, index, nullptr, 0);
    std::wstring path(static_cast<size_t>(length) + 1, L'\0');
    if (DragQueryFileW(drop, index, path.data(), length + 1) == 0) {
      continue;
    }
    path.resize(length);
    files.push_back(Utf8FromUtf16(path.c_str()));
  }
  return files;
}

std::optional<CLSID> FindImageEncoder(const wchar_t* mime_type) {
  UINT count = 0;
  UINT size = 0;
  if (Gdiplus::GetImageEncodersSize(&count, &size) != Gdiplus::Ok || size == 0) {
    return std::nullopt;
  }
  auto buffer = std::make_unique<uint8_t[]>(size);
  auto* codecs = reinterpret_cast<Gdiplus::ImageCodecInfo*>(buffer.get());
  if (Gdiplus::GetImageEncoders(count, size, codecs) != Gdiplus::Ok) {
    return std::nullopt;
  }
  for (UINT index = 0; index < count; ++index) {
    if (wcscmp(codecs[index].MimeType, mime_type) == 0) {
      return codecs[index].Clsid;
    }
  }
  return std::nullopt;
}

std::optional<std::vector<uint8_t>> EncodeBitmapAsPng(HBITMAP bitmap) {
  if (bitmap == nullptr) {
    return std::nullopt;
  }
  Gdiplus::GdiplusStartupInput input;
  ULONG_PTR token = 0;
  if (Gdiplus::GdiplusStartup(&token, &input, nullptr) != Gdiplus::Ok) {
    return std::nullopt;
  }

  std::optional<std::vector<uint8_t>> output;
  IStream* stream = nullptr;
  const auto encoder = FindImageEncoder(L"image/png");
  if (encoder && CreateStreamOnHGlobal(nullptr, TRUE, &stream) == S_OK) {
    Gdiplus::Bitmap image(bitmap, nullptr);
    if (image.GetLastStatus() == Gdiplus::Ok &&
        image.Save(stream, &*encoder, nullptr) == Gdiplus::Ok) {
      HGLOBAL memory = nullptr;
      STATSTG statistics{};
      if (GetHGlobalFromStream(stream, &memory) == S_OK &&
          stream->Stat(&statistics, STATFLAG_NONAME) == S_OK &&
          statistics.cbSize.QuadPart > 0 &&
          statistics.cbSize.QuadPart <=
              static_cast<ULONGLONG>(std::numeric_limits<SIZE_T>::max())) {
        const SIZE_T size = static_cast<SIZE_T>(statistics.cbSize.QuadPart);
        const void* data = GlobalLock(memory);
        if (data != nullptr && size > 0) {
          const auto* begin = static_cast<const uint8_t*>(data);
          output = std::vector<uint8_t>(begin, begin + size);
          GlobalUnlock(memory);
        }
      }
    }
    stream->Release();
  }
  Gdiplus::GdiplusShutdown(token);
  return output;
}

std::optional<std::vector<uint8_t>> ReadBitmapAsPng() {
  if (IsClipboardFormatAvailable(CF_BITMAP)) {
    if (const auto png =
            EncodeBitmapAsPng(static_cast<HBITMAP>(GetClipboardData(CF_BITMAP)))) {
      return png;
    }
  }
  const UINT format = IsClipboardFormatAvailable(CF_DIBV5) ? CF_DIBV5 : CF_DIB;
  if (!IsClipboardFormatAvailable(format)) {
    return std::nullopt;
  }
  HANDLE handle = GetClipboardData(format);
  if (handle == nullptr) {
    return std::nullopt;
  }
  const SIZE_T data_size = GlobalSize(handle);
  if (data_size < sizeof(BITMAPINFOHEADER)) {
    return std::nullopt;
  }
  auto* header = static_cast<BITMAPINFOHEADER*>(GlobalLock(handle));
  if (header == nullptr || header->biSize < sizeof(BITMAPINFOHEADER) ||
      header->biSize > data_size || header->biWidth <= 0 ||
      header->biHeight == 0 || header->biPlanes != 1 ||
      header->biBitCount == 0 || header->biBitCount > 32 ||
      (header->biCompression != BI_RGB &&
       header->biCompression != BI_BITFIELDS)) {
    if (header != nullptr) {
      GlobalUnlock(handle);
    }
    return std::nullopt;
  }
  size_t bits_offset = header->biSize;
  if (header->biSize == sizeof(BITMAPINFOHEADER)) {
    if (header->biBitCount <= 8) {
      const DWORD colors = header->biClrUsed != 0
                               ? header->biClrUsed
                               : (1u << header->biBitCount);
      bits_offset += static_cast<size_t>(colors) * sizeof(RGBQUAD);
    } else if (header->biCompression == BI_BITFIELDS) {
      bits_offset += 3 * sizeof(DWORD);
    }
  }
  if (bits_offset >= data_size) {
    GlobalUnlock(handle);
    return std::nullopt;
  }
  const uint64_t row_bytes =
      ((static_cast<uint64_t>(header->biWidth) * header->biBitCount + 31) /
       32) *
      4;
  const uint64_t height = header->biHeight < 0
                              ? -static_cast<int64_t>(header->biHeight)
                              : static_cast<uint64_t>(header->biHeight);
  const uint64_t required_bytes =
      header->biSizeImage == 0 ? row_bytes * height : header->biSizeImage;
  if (required_bytes == 0 || required_bytes > data_size - bits_offset) {
    GlobalUnlock(handle);
    return std::nullopt;
  }
  const auto* bits = reinterpret_cast<const uint8_t*>(header) + bits_offset;
  HDC screen = GetDC(nullptr);
  HBITMAP bitmap = CreateDIBitmap(screen, header, CBM_INIT, bits,
                                  reinterpret_cast<BITMAPINFO*>(header),
                                  DIB_RGB_COLORS);
  ReleaseDC(nullptr, screen);
  GlobalUnlock(handle);
  const auto png = EncodeBitmapAsPng(bitmap);
  if (bitmap != nullptr) {
    DeleteObject(bitmap);
  }
  return png;
}

std::optional<flutter::EncodableMap> ReadClipboard(HWND window) {
  flutter::EncodableMap output;
  ScopedClipboard clipboard(window);
  if (!clipboard.opened()) {
    return std::nullopt;
  }

  const auto files = ReadClipboardFiles();
  if (!files.empty()) {
    flutter::EncodableList encoded_files;
    encoded_files.reserve(files.size());
    for (const auto& file : files) {
      encoded_files.emplace_back(file);
    }
    output[flutter::EncodableValue("files")] =
        flutter::EncodableValue(encoded_files);
  }

  if (const auto text = ReadClipboardText()) {
    output[flutter::EncodableValue("text")] = flutter::EncodableValue(*text);
  }

  if (files.empty()) {
    struct OriginalFormat {
      const wchar_t* name;
      const char* extension;
      const char* mime;
    };
    constexpr OriginalFormat formats[] = {
        {L"PNG", "png", "image/png"},
        {L"image/png", "png", "image/png"},
        {L"JFIF", "jpg", "image/jpeg"},
        {L"image/jpeg", "jpg", "image/jpeg"},
    };
    for (const auto& format : formats) {
      const auto bytes = ReadGlobalBytes(RegisterClipboardFormatW(format.name));
      if (!bytes) {
        continue;
      }
      output[flutter::EncodableValue("imageBytes")] =
          flutter::EncodableValue(*bytes);
      output[flutter::EncodableValue("imageExtension")] =
          flutter::EncodableValue(format.extension);
      output[flutter::EncodableValue("imageMimeType")] =
          flutter::EncodableValue(format.mime);
      return output;
    }
    if (const auto png = ReadBitmapAsPng()) {
      output[flutter::EncodableValue("imageBytes")] =
          flutter::EncodableValue(*png);
      output[flutter::EncodableValue("imageExtension")] =
          flutter::EncodableValue("png");
      output[flutter::EncodableValue("imageMimeType")] =
          flutter::EncodableValue("image/png");
    }
  }
  return output;
}

std::optional<std::string> ReadVaultPath() {
  DWORD bytes = 0;
  if (RegGetValueW(HKEY_CURRENT_USER, kRegistryKey, kVaultValue,
                   RRF_RT_REG_SZ, nullptr, nullptr, &bytes) != ERROR_SUCCESS ||
      bytes < sizeof(wchar_t)) {
    return std::nullopt;
  }
  std::vector<wchar_t> value(bytes / sizeof(wchar_t), L'\0');
  if (RegGetValueW(HKEY_CURRENT_USER, kRegistryKey, kVaultValue,
                   RRF_RT_REG_SZ, nullptr, value.data(), &bytes) != ERROR_SUCCESS) {
    return std::nullopt;
  }
  const std::string path = Utf8FromUtf16(value.data());
  return path.empty() ? std::nullopt : std::optional<std::string>(path);
}

bool WriteVaultPath(const std::string& path) {
  const std::wstring wide_path = WideFromUtf8(path);
  if (wide_path.empty()) {
    return false;
  }
  HKEY key = nullptr;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, kRegistryKey, 0, nullptr, 0,
                      KEY_SET_VALUE, nullptr, &key, nullptr) != ERROR_SUCCESS) {
    return false;
  }
  const DWORD bytes =
      static_cast<DWORD>((wide_path.size() + 1) * sizeof(wchar_t));
  const LSTATUS status = RegSetValueExW(
      key, kVaultValue, 0, REG_SZ,
      reinterpret_cast<const BYTE*>(wide_path.c_str()), bytes);
  RegCloseKey(key);
  return status == ERROR_SUCCESS;
}

void ClearVaultPath() {
  HKEY key = nullptr;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, kRegistryKey, 0, KEY_SET_VALUE, &key) ==
      ERROR_SUCCESS) {
    RegDeleteValueW(key, kVaultValue);
    RegCloseKey(key);
  }
}

std::optional<std::string> ReadRegistryString(const wchar_t* value_name) {
  DWORD bytes = 0;
  if (RegGetValueW(HKEY_CURRENT_USER, kRegistryKey, value_name,
                   RRF_RT_REG_SZ, nullptr, nullptr, &bytes) != ERROR_SUCCESS ||
      bytes < sizeof(wchar_t)) {
    return std::nullopt;
  }
  std::vector<wchar_t> value(bytes / sizeof(wchar_t), L'\0');
  if (RegGetValueW(HKEY_CURRENT_USER, kRegistryKey, value_name,
                   RRF_RT_REG_SZ, nullptr, value.data(), &bytes) != ERROR_SUCCESS) {
    return std::nullopt;
  }
  const std::string s = Utf8FromUtf16(value.data());
  return s.empty() ? std::nullopt : std::optional<std::string>(s);
}

bool WriteRegistryString(const wchar_t* value_name, const std::string& s) {
  const std::wstring wide = WideFromUtf8(s);
  if (wide.empty()) {
    return false;
  }
  HKEY key = nullptr;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, kRegistryKey, 0, nullptr, 0,
                      KEY_SET_VALUE, nullptr, &key, nullptr) != ERROR_SUCCESS) {
    return false;
  }
  const DWORD bytes = static_cast<DWORD>((wide.size() + 1) * sizeof(wchar_t));
  const LSTATUS status = RegSetValueExW(
      key, value_name, 0, REG_SZ,
      reinterpret_cast<const BYTE*>(wide.c_str()), bytes);
  RegCloseKey(key);
  return status == ERROR_SUCCESS;
}

bool ShellOpen(const wchar_t* action, const std::wstring& target) {
  const HINSTANCE result =
      ShellExecuteW(nullptr, action, target.c_str(), nullptr, nullptr,
                    SW_SHOWNORMAL);
  return reinterpret_cast<INT_PTR>(result) > 32;
}

std::optional<std::string> PickFolder(HWND window) {
  IFileOpenDialog* dialog = nullptr;
  if (CoCreateInstance(CLSID_FileOpenDialog, nullptr, CLSCTX_INPROC_SERVER,
                       IID_PPV_ARGS(&dialog)) != S_OK) {
    return std::nullopt;
  }
  DWORD options = 0;
  dialog->GetOptions(&options);
  dialog->SetOptions(options | FOS_PICKFOLDERS | FOS_FORCEFILESYSTEM);
  dialog->SetTitle(L"选择采集内容的存储文件夹");
  if (dialog->Show(window) != S_OK) {
    dialog->Release();
    return std::nullopt;
  }
  IShellItem* item = nullptr;
  PWSTR path = nullptr;
  std::optional<std::string> result;
  if (dialog->GetResult(&item) == S_OK &&
      item->GetDisplayName(SIGDN_FILESYSPATH, &path) == S_OK) {
    result = Utf8FromUtf16(path);
    CoTaskMemFree(path);
  }
  if (item != nullptr) {
    item->Release();
  }
  dialog->Release();
  return result;
}

const flutter::EncodableMap* ArgumentsMap(
    const flutter::MethodCall<flutter::EncodableValue>& call) {
  return call.arguments() == nullptr
             ? nullptr
             : std::get_if<flutter::EncodableMap>(call.arguments());
}

const flutter::EncodableValue* Argument(const flutter::EncodableMap* map,
                                        const char* key) {
  if (map == nullptr) {
    return nullptr;
  }
  const auto iterator = map->find(flutter::EncodableValue(key));
  return iterator == map->end() ? nullptr : &iterator->second;
}

}  // namespace

PlatformChannels::PlatformChannels(flutter::BinaryMessenger* messenger,
                                   HWND window)
    : window_(window) {
  clipboard_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, kClipboardChannel,
          &flutter::StandardMethodCodec::GetInstance());
  clipboard_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleClipboardCall(call, std::move(result));
      });

  settings_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, kSettingsChannel,
          &flutter::StandardMethodCodec::GetInstance());
  settings_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleSettingsCall(call, std::move(result));
      });
  tray_ = std::make_unique<SystemTray>(
      window_, [this](SystemTray::Action action) { HandleTrayAction(action); });
}

PlatformChannels::~PlatformChannels() = default;

void PlatformChannels::HandleClipboardCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<MethodResult> result) {
  if (call.method_name() != "readClipboard") {
    result->NotImplemented();
    return;
  }
  const auto clipboard = ReadClipboard(window_);
  if (!clipboard) {
    result->Error("CLIPBOARD_UNAVAILABLE", "Windows 剪贴板当前正被其他程序占用");
    return;
  }
  result->Success(flutter::EncodableValue(*clipboard));
}

void PlatformChannels::HandleSettingsCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<MethodResult> result) {
  const std::string& method = call.method_name();
  if (method == "getVaultPath") {
    if (const auto path = ReadVaultPath()) {
      result->Success(flutter::EncodableValue(*path));
    } else {
      result->Success();
    }
    return;
  }
  if (method == "setVaultPath") {
    const auto* value = Argument(ArgumentsMap(call), "path");
    const auto* path = value == nullptr ? nullptr : std::get_if<std::string>(value);
    if (path == nullptr || !WriteVaultPath(*path)) {
      result->Error("BAD_ARGS", "setVaultPath 需要有效 path");
    } else {
      result->Success();
    }
    return;
  }
  if (method == "clearVaultPath") {
    ClearVaultPath();
    result->Success();
    return;
  }
  if (method == "getDisplayMethod") {
    if (const auto method_value = ReadRegistryString(kDisplayMethodValue)) {
      result->Success(flutter::EncodableValue(*method_value));
    } else {
      result->Success();
    }
    return;
  }
  if (method == "setDisplayMethod") {
    const auto* value = Argument(ArgumentsMap(call), "method");
    const auto* method_value =
        value == nullptr ? nullptr : std::get_if<std::string>(value);
    if (method_value == nullptr ||
        (*method_value != "inbox" && *method_value != "system" &&
         *method_value != "obsidian")) {
      result->Error("BAD_ARGS", "setDisplayMethod 需要 method ∈ inbox|system|obsidian");
    } else {
      WriteRegistryString(kDisplayMethodValue, *method_value);
      result->Success();
    }
    return;
  }
  if (method == "revealPath" || method == "openPath") {
    const auto* value = Argument(ArgumentsMap(call), "path");
    const auto* path =
        value == nullptr ? nullptr : std::get_if<std::string>(value);
    if (path == nullptr) {
      result->Error("BAD_ARGS", "需要 path");
      return;
    }
    const std::wstring wide = WideFromUtf8(*path);
    const wchar_t* action = method == "revealPath" ? L"explore" : L"open";
    result->Success(flutter::EncodableValue(ShellOpen(action, wide)));
    return;
  }
  if (method == "openExternalUrl") {
    const auto* value = Argument(ArgumentsMap(call), "url");
    const auto* url =
        value == nullptr ? nullptr : std::get_if<std::string>(value);
    if (url == nullptr) {
      result->Error("BAD_ARGS", "需要 url");
      return;
    }
    const std::wstring wide = WideFromUtf8(*url);
    result->Success(flutter::EncodableValue(ShellOpen(L"open", wide)));
    return;
  }
  if (method == "setWindowMode") {
    const auto* value = Argument(ArgumentsMap(call), "mode");
    const auto* mode = value == nullptr ? nullptr : std::get_if<std::string>(value);
    if (mode == nullptr || (*mode != "standard" && *mode != "floating")) {
      result->Error("BAD_ARGS", "setWindowMode 需要 mode ∈ standard|floating");
      return;
    }
    SetWindowMode(*mode == "standard");
    result->Success();
    return;
  }
  if (method == "getAppVersion") {
    result->Success(flutter::EncodableValue(
        std::to_string(FLUTTER_VERSION_MAJOR) + "." +
        std::to_string(FLUTTER_VERSION_MINOR) + "." +
        std::to_string(FLUTTER_VERSION_PATCH)));
    return;
  }
  if (method == "pickFolder") {
    if (const auto path = PickFolder(window_)) {
      result->Success(flutter::EncodableValue(*path));
    } else {
      result->Success();
    }
    return;
  }
  if (method == "setWindowSize") {
    const auto* args = ArgumentsMap(call);
    const auto* width_value = Argument(args, "width");
    const auto* height_value = Argument(args, "height");
    const auto* width = width_value == nullptr
                            ? nullptr
                            : std::get_if<double>(width_value);
    const auto* height = height_value == nullptr
                             ? nullptr
                             : std::get_if<double>(height_value);
    if (width == nullptr || height == nullptr) {
      result->Error("BAD_ARGS", "setWindowSize 需要 width/height");
      return;
    }
    if (*width <= 0 || *height <= 0) {
      result->Error("BAD_ARGS", "setWindowSize 需要正数 width/height");
      return;
    }
    ResizeWindow(*width, *height);
    result->Success();
    return;
  }
  if (method == "moveWindowBy") {
    const auto* args = ArgumentsMap(call);
    const auto* dx_value = Argument(args, "dx");
    const auto* dy_value = Argument(args, "dy");
    const auto* dx = dx_value == nullptr ? nullptr : std::get_if<double>(dx_value);
    const auto* dy = dy_value == nullptr ? nullptr : std::get_if<double>(dy_value);
    if (dx == nullptr || dy == nullptr) {
      result->Error("BAD_ARGS", "moveWindowBy 需要 dx/dy");
      return;
    }
    RECT frame{};
    GetWindowRect(window_, &frame);
    const double scale = static_cast<double>(GetDpiForWindow(window_)) / 96.0;
    SetWindowPos(window_, standard_mode_ ? HWND_NOTOPMOST : HWND_TOPMOST,
                 frame.left + static_cast<int>(*dx * scale),
                 frame.top + static_cast<int>(*dy * scale), 0, 0,
                 SWP_NOSIZE | SWP_NOACTIVATE);
    result->Success();
    return;
  }
  if (method == "beginWindowDrag") {
    dragging_ = GetCursorPos(&drag_cursor_) && GetWindowRect(window_, &drag_frame_);
    result->Success();
    return;
  }
  if (method == "updateWindowDrag") {
    if (dragging_) {
      POINT cursor{};
      if (GetCursorPos(&cursor)) {
        SetWindowPos(window_, standard_mode_ ? HWND_NOTOPMOST : HWND_TOPMOST,
                     drag_frame_.left + cursor.x - drag_cursor_.x,
                     drag_frame_.top + cursor.y - drag_cursor_.y, 0, 0,
                     SWP_NOSIZE | SWP_NOACTIVATE);
      }
    }
    result->Success();
    return;
  }
  if (method == "endWindowDrag") {
    dragging_ = false;
    result->Success();
    return;
  }
  if (method == "showWindow") {
    ShowWindow();
    result->Success();
    return;
  }
  if (method == "hideWindow") {
    ::ShowWindow(window_, SW_HIDE);
    result->Success();
    return;
  }
  if (method == "showError") {
    const auto* value = Argument(ArgumentsMap(call), "message");
    const auto* message = value == nullptr ? nullptr : std::get_if<std::string>(value);
    if (message == nullptr) {
      result->Error("BAD_ARGS", "showError 需要 message");
      return;
    }
    MessageBoxW(window_, WideFromUtf8(*message).c_str(), L"INbox",
                MB_OK | MB_ICONERROR);
    result->Success();
    return;
  }
  if (method == "quit") {
    quit_requested_ = true;
    PostMessage(window_, WM_CLOSE, 0, 0);
    result->Success();
    return;
  }
  result->NotImplemented();
}

std::optional<LRESULT> PlatformChannels::HandleWindowMessage(
    UINT message, WPARAM wparam, LPARAM lparam) {
  if (tray_ && tray_->HandleMessage(message, wparam, lparam)) {
    return 0;
  }
  if (message == WM_CLOSE && !quit_requested_) {
    if (standard_mode_) {
      settings_channel_->InvokeMethod("mainWindowDidClose", nullptr);
    } else {
      ::ShowWindow(window_, SW_HIDE);
    }
    return 0;
  }
  return std::nullopt;
}

void PlatformChannels::ShowWindow() {
  ::ShowWindow(window_, SW_RESTORE);
  SetForegroundWindow(window_);
}

void PlatformChannels::SetWindowMode(bool standard) {
  standard_mode_ = standard;
  const LONG_PTR style = standard
      ? (WS_OVERLAPPEDWINDOW & ~(WS_THICKFRAME | WS_MAXIMIZEBOX)) |
            WS_CLIPCHILDREN
      : WS_POPUP | WS_CLIPCHILDREN;
  LONG_PTR ex_style = GetWindowLongPtr(window_, GWL_EXSTYLE);
  if (standard) {
    ex_style &= ~(WS_EX_TOOLWINDOW | WS_EX_TOPMOST | WS_EX_LAYERED);
    ex_style |= WS_EX_APPWINDOW;
  } else {
    ex_style &= ~WS_EX_APPWINDOW;
    ex_style |= WS_EX_TOOLWINDOW | WS_EX_TOPMOST | WS_EX_LAYERED;
  }
  SetWindowLongPtr(window_, GWL_STYLE, style);
  SetWindowLongPtr(window_, GWL_EXSTYLE, ex_style);
  if (!standard) {
    SetLayeredWindowAttributes(window_, RGB(255, 0, 255), 255, LWA_COLORKEY);
  }
  SetWindowPos(window_, standard ? HWND_NOTOPMOST : HWND_TOPMOST, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_FRAMECHANGED |
                   SWP_SHOWWINDOW);
}

void PlatformChannels::ResizeWindow(double width, double height) {
  const UINT dpi = GetDpiForWindow(window_);
  const double scale = static_cast<double>(dpi) / 96.0;
  RECT frame{};
  GetWindowRect(window_, &frame);
  RECT desired{0, 0, static_cast<LONG>(std::lround(width * scale)),
               static_cast<LONG>(std::lround(height * scale))};
  if (standard_mode_) {
    AdjustWindowRectExForDpi(&desired,
                             static_cast<DWORD>(GetWindowLongPtr(window_, GWL_STYLE)),
                             FALSE,
                             static_cast<DWORD>(GetWindowLongPtr(window_, GWL_EXSTYLE)),
                             dpi);
  }
  int target_width = desired.right - desired.left;
  int target_height = desired.bottom - desired.top;
  const HMONITOR monitor = MonitorFromWindow(window_, MONITOR_DEFAULTTONEAREST);
  MONITORINFO info{sizeof(info)};
  GetMonitorInfoW(monitor, &info);
  const int work_width = static_cast<int>(info.rcWork.right - info.rcWork.left);
  const int work_height = static_cast<int>(info.rcWork.bottom - info.rcWork.top);
  target_width = (std::min)(target_width, work_width);
  target_height = (std::min)(target_height, work_height);
  int x = standard_mode_ ? frame.left : frame.right - target_width;
  int y = frame.top;
  x = (std::max)(static_cast<int>(info.rcWork.left),
                 (std::min)(x, static_cast<int>(info.rcWork.right) - target_width));
  y = (std::max)(static_cast<int>(info.rcWork.top),
                 (std::min)(y, static_cast<int>(info.rcWork.bottom) - target_height));
  SetWindowPos(window_, standard_mode_ ? HWND_NOTOPMOST : HWND_TOPMOST,
               x, y, target_width, target_height,
               SWP_NOACTIVATE | SWP_SHOWWINDOW);
}

void PlatformChannels::HandleTrayAction(SystemTray::Action action) {
  switch (action) {
    case SystemTray::Action::toggleWindow:
      if (IsWindowVisible(window_) && !IsIconic(window_)) {
        ::ShowWindow(window_, SW_HIDE);
      } else {
        ShowWindow();
      }
      break;
    case SystemTray::Action::changeVault:
      settings_channel_->InvokeMethod(
          "trayAction", std::make_unique<flutter::EncodableValue>("changeVault"));
      break;
    case SystemTray::Action::openVault:
      settings_channel_->InvokeMethod(
          "trayAction", std::make_unique<flutter::EncodableValue>("openVault"));
      break;
    case SystemTray::Action::checkUpdates:
      settings_channel_->InvokeMethod(
          "trayAction", std::make_unique<flutter::EncodableValue>("checkUpdates"));
      break;
    case SystemTray::Action::quit:
      quit_requested_ = true;
      PostMessage(window_, WM_CLOSE, 0, 0);
      break;
  }
}
