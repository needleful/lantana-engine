// Part of NP-ToDo
// copyright Devin Lee Hastings a.k.a. needleful

module app.main;

import core.memory;
import core.thread.osthread: Thread;
import core.time;

import std.format;
import std.math;
import std.stdio;

import bindbc.sdl;

import lantana.input;
import lantana.math;
import lantana.render;
import lantana.types;
import lantana.ui;

import app.todo;
import app.ui;

private enum forcedMain = true;

static if(forcedMain)
{
	int main()
	{
		writeln("Starting Lantana in main...");
		return runGame();
	}
}
else version(Windows)
{
	import core.runtime;
	import core.sys.windows.windows;
	import std.string : toStringz;

	extern(Windows)
	int WinMain(HINSTANCE p_instance, HINSTANCE p_prev, LPSTR p_command, int p_show)
	{
		int result;
		try
		{
			Runtime.initialize();
			result = runGame();
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
else
{
	int main()
	{
		writeln("Starting Lantana in main...");
		return runGame();
	}
}

int runGame()
{
	Window window = Window(1280, 720, "NP ToDo");
	auto ui = makeRenderer(window);

	auto editor = new ProjectEditor(loadProject("np-todo.todo"));
	ui.setRootWidget(editor);

	Input input = Input();
	float delta = 0.001f;

	window.grabMouse(false);

	while(!window.state[WindowState.CLOSED])
	{
		delta = window.delta_ms()/1000.0;
	
		window.pollEvents(&input);

		if(window.state[WindowState.RESIZED])
		{
			ui.setSize(window.getSize());
		}

		ui.updateInteraction(delta, &input);
		ui.updateLayout();

		if(ui.needsRedraw) {
			ui.render();
			window.endFrame();
		}
		else {
			Thread.sleep(dur!"msecs"(16));
		}
	}
	return 0;
}