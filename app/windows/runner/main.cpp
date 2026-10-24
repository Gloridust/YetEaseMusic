#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <cwchar>

#include "flutter_window.h"
#include "utils.h"

namespace {

// 主窗口上挂的标记，第二个实例据此找到它（标题随系统语言变化，不能按标题找）
constexpr wchar_t kMainWindowProp[] = L"YetEaseMusicMainWindow";

BOOL CALLBACK ShowExistingWindow(HWND hwnd, LPARAM found) {
  if (::GetPropW(hwnd, kMainWindowProp) == nullptr) return TRUE;
  ::ShowWindow(hwnd, ::IsIconic(hwnd) ? SW_RESTORE : SW_SHOW);
  ::SetForegroundWindow(hwnd);
  *reinterpret_cast<bool*>(found) = true;
  return FALSE;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // 只允许一个主程序实例：窗口关到托盘后再次启动，就把已有窗口显示出来。
  // 桌面歌词是同一程序的另一个进程，不受此限制。
  const bool lyrics_mode = std::wcsstr(command_line, L"--desktop-lyrics") != nullptr;
  HANDLE instance_mutex = nullptr;
  if (!lyrics_mode) {
    instance_mutex = ::CreateMutexW(nullptr, FALSE, L"Local\\io.github.gloridust.YetEaseMusic");
    if (::GetLastError() == ERROR_ALREADY_EXISTS) {
      bool found = false;
      ::EnumWindows(ShowExistingWindow, reinterpret_cast<LPARAM>(&found));
      if (found) return EXIT_SUCCESS;
    }
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"YetEase Music", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);
  if (!lyrics_mode) ::SetPropW(window.GetHandle(), kMainWindowProp, reinterpret_cast<HANDLE>(1));

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  if (instance_mutex != nullptr) ::CloseHandle(instance_mutex);
  return EXIT_SUCCESS;
}
