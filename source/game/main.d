// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.main;
version(lantana_game):

import std.format;
import std.stdio;

import gl3n.linalg : vec3, vec2;

import lantana.input;
import lantana.math;
import lantana.render;
import lantana.types.layout;
import lantana.types.memory;

// Force the game to run on main() instead of WinMain()
enum forcedMain = false;

enum MAIN_MEM_LIMIT = 1024*1024*16;

float camFOV = 70;

int runGame()
{
	Window window = Window(1280, 720, "Texting my Boyfriend while Dying in Space");
	window.grabMouse(false);
	Input input = Input();

	auto mainMem = BaseRegion(MAIN_MEM_LIMIT);

	auto camera = OrbitalCamera(vec3(0), 1280.0/720.0, camFOV, vec2(0, 60));
	camera.distance = 9;

	// Loading the ground plane
		auto sMeshSys = StaticMesh.System("data/shaders/worldspace3d.vert", "data/shaders/material3d.frag");
		sMeshSys.reserveMeshes(mainMem, 1);

		auto worldMeshes = sMeshSys.loadMeshes("data/meshes/test-world.glb", mainMem);
		auto stInst = mainMem.makeList!(StaticMesh.Instance)(1);

		stInst[0] = StaticMesh.Instance(worldMeshes["Plane"], Transform(1));

		StaticMesh.Uniforms.global stUniforms;
		with(stUniforms)
		{
			light_direction = vec3(0, -1, 0);
			light_bias = 0;
			area_span = 5;
			area_ceiling = -4;
			gamma = 2.2;
			nearPlane = camera.nearPlane;
			farPlane = camera.farPlane;
			tex_albedo = 0;
		}
		auto palette = LightPalette("data/palettes/lightPalette.png", mainMem);
	// end

	while(!window.state[WindowState.CLOSED])
	{	
		window.pollEvents(&input);

		if(window.state[WindowState.RESIZED])
		{
			RealSize ws = window.getSize();
			camera.setProjection(ws.width/cast(float)ws.height, camFOV);
		}

		window.beginFrame();

		auto vp = camera.vp();

		stUniforms.projection = vp;

		sMeshSys.render(stUniforms, palette.palette, stInst);

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