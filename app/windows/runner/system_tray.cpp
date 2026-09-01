#include "system_tray.h"

#include <utility>
#include "resource.h"

namespace {
constexpr UINT kTrayMessage = WM_APP + 40;
constexpr UINT kToggle = 1;
constexpr UINT kChangeVault = 2;
constexpr UINT kOpenVault = 3;
constexpr UINT kCheckUpdates = 4;
constexpr UINT kQuit = 5;
}

SystemTray::SystemTray(HWND window, std::function<void(Action)> on_action)
    : window_(window), on_action_(std::move(on_action)),
      taskbar_created_(RegisterWindowMessageW(L"TaskbarCreated")) {
  icon_.cbSize = sizeof(icon_);
  icon_.hWnd = window_;
  icon_.uID = 1;
  icon_.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP | NIF_SHOWTIP;
  icon_.uCallbackMessage = kTrayMessage;
  icon_.hIcon = LoadIcon(GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON));
  if (!icon_.hIcon) icon_.hIcon = LoadIcon(nullptr, IDI_APPLICATION);
  wcscpy_s(icon_.szTip, L"INbox · 点击桌宠采集");
  AddIcon();
}

SystemTray::~SystemTray() { Shell_NotifyIconW(NIM_DELETE, &icon_); }

void SystemTray::AddIcon() {
  if (Shell_NotifyIconW(NIM_ADD, &icon_)) {
    icon_.uVersion = NOTIFYICON_VERSION_4;
    Shell_NotifyIconW(NIM_SETVERSION, &icon_);
  }
}

bool SystemTray::HandleMessage(UINT message, WPARAM, LPARAM lparam) {
  if (taskbar_created_ != 0 && message == taskbar_created_) {
    AddIcon();
    return true;
  }
  if (message != kTrayMessage) return false;
  switch (LOWORD(lparam)) {
    case NIN_SELECT:
    case NIN_KEYSELECT:
      on_action_(Action::toggleWindow);
      break;
    case WM_CONTEXTMENU:
      ShowMenu();
      break;
  }
  return true;
}

void SystemTray::ShowMenu() {
  HMENU menu = CreatePopupMenu();
  if (!menu) return;
  AppendMenuW(menu, MF_STRING, kToggle,
      IsWindowVisible(window_) && !IsIconic(window_) ? L"隐藏 INbox" : L"显示 INbox");
  AppendMenuW(menu, MF_STRING, kChangeVault, L"更改存储文件夹");
  AppendMenuW(menu, MF_STRING, kOpenVault, L"打开存储文件夹");
  AppendMenuW(menu, MF_STRING, kCheckUpdates, L"检查更新（发布页）");
  AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(menu, MF_STRING, kQuit, L"退出 INbox");
  POINT cursor{};
  GetCursorPos(&cursor);
  SetForegroundWindow(window_);
  const UINT selected = TrackPopupMenuEx(menu,
      TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON,
      cursor.x, cursor.y, window_, nullptr);
  DestroyMenu(menu);
  PostMessage(window_, WM_NULL, 0, 0);
  switch (selected) {
    case kToggle: on_action_(Action::toggleWindow); break;
    case kChangeVault: on_action_(Action::changeVault); break;
    case kOpenVault: on_action_(Action::openVault); break;
    case kCheckUpdates: on_action_(Action::checkUpdates); break;
    case kQuit: on_action_(Action::quit); break;
  }
}
