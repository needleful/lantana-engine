
module app.platform.windows;

version(Windows):

import core.runtime;
import core.sys.windows.windows;
import std.format;
import std.stdio;
import std.string : toStringz;

import bindbc.sdl;

import lantana.render.window;
import lantana.ui.keyboard;

import app.main;
import app.ui;

private enum forcedMain = false;
static if(forcedMain)
{
	int main()
	{
		writeln("NP-ToDo forced to start in main...");
		return run();
	}
}
else
{
	extern(Windows)
	int WinMain(HINSTANCE p_instance, HINSTANCE p_prev, LPSTR p_command, int p_show)
	{
		int result;
		try
		{
			Runtime.initialize();
			result = run();
			Runtime.terminate();
		}
		catch(Throwable e)
		{
			auto msg = format("There was an error:\r\n%s"w, e);
			msg ~= '\0';
			MessageBoxW(null, msg.ptr, null, MB_ICONEXCLAMATION);
			result = 0;
		}
		return result;
	}
}

void createMenu(ref Window window, action[] fileActions, void delegate()[ushort] shortcuts) {
	SDL_SysWMinfo sysInfo;
	SDL_GetWindowWMInfo(window.window, &sysInfo);

	HWND hwnd = sysInfo.info.win.window;
	HMENU menubar = CreateMenu();
	HMENU fileMenu = CreateMenu();
	
	AppendMenu(menubar, MF_POPUP, cast(UINT_PTR) fileMenu, "&File");
	import std.conv: to;
	foreach(ref action a; fileActions) {
		wstring name = to!(wstring)(a.name ~ '\t' ~ a.shortcut.toString());
		AppendMenu(fileMenu, MF_STRING, cast(UINT_PTR) a.shortcut.toInt(), name.ptr);
	}
	SetMenu(hwnd, menubar);

	SDL_EventState(SDL_SYSWMEVENT, SDL_ENABLE);

	window.onSystemMessage = (ref Window w, SDL_SysWMmsg* msg) nothrow {
		try {
			if(msg.msg.win.msg == WM_COMMAND) {
				auto cmd = LOWORD(msg.msg.win.wParam);
				if (cmd in shortcuts) {
					shortcuts[cmd]();
				}
			}
		}
		catch(Exception e) {
			puts("Whoops!");
		}
	};
}