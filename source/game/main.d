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
enum followActor = false;

enum MAIN_MEM_LIMIT = 1024*1024*16;

// Degrees
float camFOV = 70;
// Degrees per second
float camSpeed = 60;

int runGame()
{
	Window window = Window(1280, 720, "Bipples");
	window.grabMouse(false);
	Input input = Input();

	auto mainMem = BaseRegion(MAIN_MEM_LIMIT);

	auto camera = OrbitalCamera(vec3(0), 1280.0/720.0, camFOV, vec2(0, 60));
	camera.distance = 9;

	int worldScale = 1;

	Room world = Room(vec3(0), ivec2(-5*worldScale), ivec2(5*worldScale));
	Actor actor = Actor(&world);

	// Loading the ground plane
		auto sMeshSys = StaticMesh.System("data/shaders/worldspace3d.vert", "data/shaders/material3d.frag");
		sMeshSys.reserveMeshes(mainMem, 5);

		auto worldMeshes = sMeshSys.loadMeshes("data/meshes/test-world.glb", mainMem);
		auto stInst = mainMem.makeList!(StaticMesh.Instance)(cast(ulong)(3 + 1*worldScale*worldScale));

		stInst[0..3] = [
			StaticMesh.Instance(worldMeshes["Floor"], Transform(worldScale)),
			StaticMesh.Instance(worldMeshes["Target"], Transform(1)),
			StaticMesh.Instance(worldMeshes["Actor"], Transform(1))
		];

		import std.random;
		auto rnd = Random(5033);
		// Random obstacles
		for(int i = 3; i < stInst.length; i++)
		{
			ivec2 p = ivec2(
				uniform(world.grid.lowBounds.x, world.grid.highBounds.x, rnd),
				uniform(world.grid.lowBounds.y, world.grid.highBounds.y, rnd)
				);
			if(p == ivec2(0,0))
			{
				p = ivec2(1,1);
			}

			world.grid.removePoint(p);
			stInst[i] = StaticMesh.Instance(worldMeshes["Wall"], Transform(1, world.getWorldPosition(p)));
		}

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

	ivec2 targetPos;

	float reset_timer = 0;
	bool gave_up;
	enum RESET_TIME = 3;

	bool orbit = false;
	import std.datetime.stopwatch;
	StopWatch searchTime = StopWatch(AutoStart.no);
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
			if(actor.gridPos == targetPos || reset_timer >= RESET_TIME)
			{
				reset_timer = 0;
				targetPos = ivec2(
					uniform(world.grid.lowBounds.x, world.grid.highBounds.x, rnd),
					uniform(world.grid.lowBounds.y, world.grid.highBounds.y, rnd)
				);
				assert(world.grid.inBounds(targetPos));
				searchTime.start();
				gave_up = !actor.approach(targetPos);
				searchTime.stop();

				//writefln("Searched in %s usec. %s", searchTime.peek.total!"usecs"(), gave_up?"Failed" : "Found path");
				writeln(searchTime.peek.total!"usecs"());
				stdout.flush();

				searchTime.reset();

				trTarget._position = world.getWorldPosition(targetPos);
			}

			actor.update(delta);
			trActor._position = actor.worldPos();
			static if(followActor)
			{
				camera.target = trActor._position;
			}

			if(gave_up)
			{
				reset_timer += delta;
			}
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