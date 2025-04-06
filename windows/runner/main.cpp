#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
        _In_ wchar_t *command_line, _In_ int show_command) {
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

// Get the usable screen area (excluding the taskbar)
RECT work_area;
SystemParametersInfo(SPI_GETWORKAREA, 0, &work_area, 0);

int usable_width = work_area.right - work_area.left;
int usable_height = work_area.bottom - work_area.top;

// Calculate window position and size
int window_left = usable_width / 8;          // 1/6th of the usable width
int window_top = work_area.top + 24;         // 24 pixels above the usable area
int window_width = 3 * (usable_width / 5);   // 3/5ths of the usable width
int window_height = usable_height - 48;      // Usable height minus 24px at top and bottom

FlutterWindow window(project);
Win32Window::Point origin(window_left, window_top);
Win32Window::Size size(window_width, window_height);
if (!window.Create(L"httpd Settings", origin, size)) {
return EXIT_FAILURE;
}

// Disable close button to not press by mistake
//HWND hwnd = window.GetHandle();
//HMENU hmenu = GetSystemMenu(hwnd, FALSE);
//EnableMenuItem(hmenu, SC_CLOSE, MF_GRAYED);

window.SetQuitOnClose(true);

::MSG msg;
while (::GetMessage(&msg, nullptr, 0, 0)) {
::TranslateMessage(&msg);
::DispatchMessage(&msg);
}

::CoUninitialize();
return EXIT_SUCCESS;
}
