#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <algorithm>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);

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
  Win32Window::Point origin(0, 0);
  Win32Window::Size size(1360, 920);
  if (!window.Create(L"Study", origin, size)) {
    return EXIT_FAILURE;
  }

  HWND handle = window.GetHandle();
  double scale = GetDpiForWindow(handle) / 96.0;
  RECT work_area;
  SystemParametersInfoW(SPI_GETWORKAREA, 0, &work_area, 0);
  int available_width = static_cast<int>((work_area.right - work_area.left) / scale);
  int available_height = static_cast<int>((work_area.bottom - work_area.top) / scale);
  int logical_width = std::min({1360, available_width, std::max(960, available_width - 40)});
  int logical_height = std::min({920, available_height, std::max(620, available_height - 40)});
  int window_width = static_cast<int>(logical_width * scale);
  int window_height = static_cast<int>(logical_height * scale);
  int window_x = work_area.left + ((work_area.right - work_area.left) - window_width) / 2;
  int window_y = work_area.top + ((work_area.bottom - work_area.top) - window_height) / 2;
  SetWindowPos(handle, nullptr, window_x, window_y, window_width, window_height,
               SWP_NOZORDER | SWP_NOACTIVATE);

  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
