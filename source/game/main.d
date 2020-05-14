// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.main;
version(lantana_game):

import std.format;
import std.stdio;

import game.scene;

import lantana.input;
import lantana.math;
import lantana.render;
import lantana.types.layout;
import lantana.types.memory;

// Force the game to run on main() instead of WinMain()
enum forcedMain = true;

enum MAIN_MEM_LIMIT = 1024*1024*8;

int runGame()
{
	Window window = Window(1280, 720, "Bipples");
	window.grabMouse(false);
	Input input = Input();

	auto mainMem = BaseRegion(MAIN_MEM_LIMIT);

	auto scene = new SceneManager(mainMem);
	scene.load("data/scenes/test.sdl");

	while(!window.state[WindowState.CLOSED])
	{
		window.pollEvents(&input);
		float delta = window.delta_ms()/1000;

		if(window.state[WindowState.RESIZED])
		{
			RealSize ws = window.getSize();
			scene.camera.setProjection(ws.width/cast(float)ws.height, camFOV);
		}

		scene.update(delta);

		window.beginFrame();
		scene.render();
		window.endFrame();
	}

	debug writeln("Game closing");
	return 0;
}



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
		return runGame();
	}
}