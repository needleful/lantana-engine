// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.main;
version(lantana_game):

import std.format;
import std.stdio;

import bindbc.sdl;
import gl3n.linalg : vec3, vec2;

import game.actor;
import game.map;

import lantana.input;
import lantana.math;
import lantana.render;
import lantana.types.layout;
import lantana.types.memory;

// Force the game to run on main() instead of WinMain()
enum forcedMain = false;

enum MAIN_MEM_LIMIT = 1024*1024*8;

// Degrees
float camFOV = 70;
// Degrees per second
float camSpeed = 60;

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
		sMeshSys.reserveMeshes(mainMem, 5);

		auto worldMeshes = sMeshSys.loadMeshes("data/meshes/test-world.glb", mainMem);
		auto stInst = mainMem.makeList!(StaticMesh.Instance)(3);

		stInst[0..$] = [
			StaticMesh.Instance(worldMeshes["Floor"], Transform(1)),
			StaticMesh.Instance(worldMeshes["Target"], Transform(1)),
			StaticMesh.Instance(worldMeshes["Actor"], Transform(1))
		];

		Transform* trTarget = &stInst[1].transform;
		Transform* trActor = &stInst[2].transform;

		StaticMesh.Uniforms.global stUniforms;
		with(stUniforms)
		{
			light_direction = vec3(0, -1, -0.2);
			light_bias = 0;
			area_span = 3;
			area_ceiling = -1.5;
			gamma = 2.2;
			nearPlane = camera.nearPlane;
			farPlane = camera.farPlane;
			tex_albedo = 0;
		}
		auto palette = LightPalette("data/palettes/lightPalette.png", mainMem);
	// end

	Room world = Room(vec3(0), ivec2(-5), ivec2(5));
	Actor actor = Actor(&world);
	ivec2 targetPos;

	bool orbit = false;
	while(!window.state[WindowState.CLOSED])
	{
		// Fundamentals
		window.pollEvents(&input);
		float delta = window.delta_ms()/1000;

		if(window.state[WindowState.RESIZED])
		{
			RealSize ws = window.getSize();
			camera.setProjection(ws.width/cast(float)ws.height, camFOV);
		}
		// end Fundamentals

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
				if(camera.angle.y + camRot.y > 90 || camera.angle.y + camRot.y < 5)
				{
					camRot.y = 0;
				}
				camera.rotateDegrees(camRot);
			}
			
			float zoom = input.mouseWheel.y*80*delta;
			if(camera.distance + zoom < 0 || camera.distance + zoom > 40)
			{
				zoom = 0;
			}
			camera.distance += zoom;
		// end camera controls

		// Random target movement
			if(actor.gridPos == targetPos)
			{
				targetPos += ivec2(117, 31);
				targetPos = ivec2(targetPos.x % world.grid.width(), targetPos.y % world.grid.height());
				targetPos += world.grid.lowBounds;
				actor.approach(targetPos);

				writeln(actor.plan);

				trTarget._position = world.getWorldPosition(targetPos);
			}

			actor.update(delta);
			trActor._position = actor.worldPos();
		// target end

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