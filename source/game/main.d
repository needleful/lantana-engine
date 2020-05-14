// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.main;
version(lantana_game):

import std.format;
import std.stdio;

import gl3n.linalg : vec2;

import game.scene;

import lantana.input;
import lantana.math;
import lantana.render;
import lantana.types.layout;
import lantana.types.memory;

// Force the game to run on main() instead of WinMain()
enum forcedMain = true;

enum MAIN_MEM_LIMIT = 1024*1024*18;

int runGame()
{
	Window window = Window(1280, 720, "Bipples");
	window.grabMouse(false);
	Input input = Input();

	auto mainMem = BaseRegion(MAIN_MEM_LIMIT);

	auto scene = new SceneManager(mainMem);
	scene.load("data/scenes/test.sdl");

	bool orbit = false;
	while(!window.state[WindowState.CLOSED])
	{
		window.pollEvents(&input);
		float delta = window.delta_ms()/1000;

		if(window.state[WindowState.RESIZED])
		{
			RealSize ws = window.getSize();
			scene.camera.setProjection(ws.width/cast(float)ws.height, camFOV);
		}

	 	// Camera controls
		bool newOrbit = input.isClicked(Input.Mouse.Right) || input.isClicked(Input.Mouse.Middle);
		if(orbit != newOrbit)
		{
			orbit = newOrbit;
			window.grabMouse(orbit);
		}
		if(orbit)
		{
			vec2 camRot = input.mouseMove*camSpeed*delta;
			camRot.y *= -1;
			if(scene.camera.angle.y + camRot.y > 90 || scene.camera.angle.y + camRot.y < 5)
			{
				camRot.y = 0;
			}
			scene.camera.rotateDegrees(camRot);
		}
		import std.math: pow;
		float zoom = pow(1.2, input.mouseWheel.y);
		if(scene.camera.distance*zoom < 0.001 || scene.camera.distance*zoom > 40)
		{
			zoom = 1;
		}
		scene.camera.distance *= zoom;
		// end camera controls

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