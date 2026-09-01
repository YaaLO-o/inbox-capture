#ifndef RUNNER_SYSTEM_TRAY_H_
#define RUNNER_SYSTEM_TRAY_H_

#include <windows.h>
#include <shellapi.h>
#include <functional>

// Owns only the shell icon and its menu. No clipboard, settings or Vault access.
class SystemTray {
 public:
  enum class Action { toggleWindow, changeVault, openVault, checkUpdates, quit };
  SystemTray(HWND window, std::function<void(Action)> on_action);
  ~SystemTray();
  bool HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);
 private:
  void AddIcon();
  void ShowMenu();
  HWND window_;
  std::function<void(Action)> on_action_;
  NOTIFYICONDATAW icon_{};
  UINT taskbar_created_;
};

#endif
