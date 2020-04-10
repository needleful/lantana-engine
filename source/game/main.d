// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.main;

import core.memory;
import std.concurrency;
import std.format;
import std.math;
import std.stdio;

import bindbc.sdl;

import lantana.audio;
import lantana.file.gltf2;
import lantana.file.lgbt;
import lantana.input;
import lantana.math;
import lantana.render;
import lantana.render.buffer;
import lantana.types;
import lantana.ui;

import game.dialog;
import game.skybox;
import game.ui;
import gl3n.linalg;


enum MAX_MEMORY = 1024*1024*64;
enum cam_speed = 1;

__gshared float g_timescale = 1;
__gshared float g_oxygen = 21.2;
__gshared float g_oxygenDrain = 0.027;

struct Velocity
{
	Transform* transform;
	vec3 translate;
	vec3 rotate;

	this(Transform* p_transform, vec3 p_translate, vec3 p_rotate)
	{
		transform = p_transform;
		translate = p_translate;
		rotate = p_rotate;
	}
}

//version(lantana_game)
//int main()
//{
//	SDLSupport sdlresult = loadSDL();
//	assert(sdlresult == sdlSupport, "Could not load SDL2");

//	SDL_Init(SDL_INIT_VIDEO);
//	SDL_Window* window = SDL_CreateWindow(
//			"Lantana Test", 
//			cast(int)SDL_WINDOWPOS_CENTERED, 
//			cast(int)SDL_WINDOWPOS_CENTERED, 
//			1280, 720, 
//			SDL_WINDOW_RESIZABLE);

//	SDL_Delay(5000);
//	SDL_DestroyWindow(window);
//	SDL_Quit();
//	return 0;
//}

version(lantana_game)
int main()
{
	Window window = Window(1280, 720, "Texting my Boyfriend while Dying in Space");
	RealSize ws = window.getSize();
	assert(ws.width == 1280);
	g_ui = new UIRenderer(ws);

	Input input = Input();
	g_uiInput = new Input(input);
	auto uiThread = spawn(&uiMain);

	AudioManager audio = AudioManager(32);
	audio.startMusic("data/audio/music/floating-full.ogg", 0);

	auto mainMem = BaseRegion(MAX_MEMORY);
	auto camera = LongRangeOrbitalCamera(vec3(0), cast(float)ws.width/ws.height, 60, vec2(20, 0));
	camera.target = vec3(0);
	camera.distance = 5;

	auto skyBox = SkyMesh.System("data/shaders/skybox.vert", "data/shaders/skybox.frag");
	skyBox.reserveMeshes(mainMem, 1);
	auto sky = skyBox.loadMeshes("data/meshes/skybox.glb", mainMem);
	SkyMesh.Instance[] skyMeshes = mainMem.makeList!(SkyMesh.Instance)(1);
	skyMeshes[0] = SkyMesh.Instance(sky.first(), Transform(0.5));

	SkyMesh.Uniforms.global skyUni;
	skyUni.gamma = 1.8;

	auto anim = AnimMesh.System("data/shaders/animated3d.vert", "data/shaders/material3d.frag");
	anim.reserveMeshes(mainMem, 1);

	AnimMesh.Uniforms.global animGlobals;
	animGlobals.light_direction = vec3(-0.1,-0.3,0.9);
	animGlobals.light_bias = 0.0;
	animGlobals.area_ceiling = -1;
	animGlobals.area_span = 3;
	animGlobals.gamma = 1;
	animGlobals.nearPlane = camera.nearPlane;
	animGlobals.farPlane = camera.farPlane;

	auto pMeshes = anim.loadMeshes("data/meshes/kitty-astronaut.glb", mainMem);
	auto pInstance = mainMem.makeList!(AnimMesh.Instance)(1);
	pInstance[0] = AnimMesh.Instance(pMeshes.first(), Transform(1, vec3(0), vec3(0, -40, 180)), mainMem);
	pInstance[0].play("Idle", true);


	auto sMesh = StaticMesh.System("data/shaders/worldspace3d.vert", "data/shaders/material3d.frag");
	sMesh.reserveMeshes(mainMem, 5);

	StaticMesh.Uniforms.global sGlobals;
	sGlobals.light_direction = animGlobals.light_direction;
	sGlobals.light_bias = animGlobals.light_bias;
	sGlobals.area_span = 800;
	sGlobals.area_ceiling = 0;
	sGlobals.gamma = animGlobals.gamma;
	sGlobals.nearPlane = camera.nearPlane;
	sGlobals.farPlane = camera.farPlane;

	auto shipMesh = sMesh.loadMeshes("data/meshes/ship.glb", mainMem);
	auto sInstance = mainMem.makeList!(StaticMesh.Instance)(5);
	sInstance[] = [
		StaticMesh.Instance(shipMesh["Ship"], Transform(1, vec3(10, 25, -30), vec3(12, 143, -90))),
		StaticMesh.Instance(shipMesh["LargePanel"], Transform(1, vec3(40, 30, -36), vec3(12, 148, -90))),
		StaticMesh.Instance(shipMesh["Corridor"], Transform(1, vec3(-10, 9, -20), vec3(4, 23, 18))),
		StaticMesh.Instance(shipMesh["Door1"], Transform(1, vec3(-9, 10.5, -18), vec3(0))),
		StaticMesh.Instance(shipMesh["Door2"], Transform(1, vec3(12, 2, 4), vec3(20)))
	];

	auto velocities = mainMem.makeList!Velocity(6);
	velocities[] = [
		Velocity(&(pInstance[0].transform), vec3(0), vec3(-0.1, 1.2, 0.71)),
		Velocity(&(sInstance[0].transform), vec3(.3, .6, -1.2), vec3(2, -1, -2.5)),
		Velocity(&(sInstance[1].transform), vec3(-.1, .4, -2), vec3(4, -9, 1)),
		Velocity(&(sInstance[2].transform), vec3(.2, .5, -.6), vec3(3, -2, -2)),
		Velocity(&(sInstance[3].transform), vec3(-.05, .73, -.4), vec3(2, 1, 2)),
		Velocity(&(sInstance[4].transform), vec3(.4, .28, .9), vec3(1.75, -1.25, 0))
	];

	auto lights = LightPalette("data/palettes/lightPalette.png", mainMem);

	float runningMaxDelta_ms = -1;
	float accumDelta_ms = 0;
	bool paused = false;

	uint frame = 0;
	string debugFormat = ": %6.3f\n: %6.3f\n: %6.3f";
	string oxygenFormat = "Oxygen: %.2f%%";

	receive(
			(UIReady _){},
			(UICancel _){
				throw new Exception("Failed to launch UI");
			}
		);

	g_ui.initialize();

	float delta = 0.001f;

	uiThread.send(UIEvents(delta, window.state, window.getSize()));

	vec2 velCamRot = vec2(0);
	float accelCamRot = 60;
	float dampCamRot = 0.99;

	debug
	{
		File frame_log = File("logs/framerate.tsv", "w");
		frame_log.writeln("Frametime\tMax\tAverage");
	}

	enum uiFrameRate = 1/45.0;
	float uiFrameTime = 0;
	int runningFrame = 1;
	float time_accum = 0;
	FrameBuffer scene3D = FrameBuffer("data/shaders/buffer.vert", "data/shaders/fxaa.frag", ws, 1.0);
	g_oxygenText = format(oxygenFormat, g_oxygen);

	while(!window.state[WindowState.CLOSED])
	{
		float delta_ms = window.delta_ms();
		delta = g_timescale*delta_ms/1000.0;
		uiFrameTime += delta;
	
		window.pollEvents(&input);

		if(window.state[WindowState.RESIZED])
		{
			ws = window.getSize();
			camera.setProjection(cast(float)ws.width/ws.height, 60);
			scene3D.resize(ws);
			input.mouseMove = vec2(0);
		}

		if(input.keyboard.isJustPressed(SDL_SCANCODE_TAB))
		{
			paused = !paused;
			window.grab_mouse(!paused);
		}

		if(!paused)
		{
			velCamRot += input.mouseMove*delta*accelCamRot;
		}
		velCamRot *= dampCamRot;
		vec2 camRot = velCamRot*cam_speed*delta;
		camRot.y *= -1;

		foreach(vel; velocities)
		{
			vel.transform.translate(vel.translate*delta);
			vel.transform.rotateDegrees(vel.rotate*delta);
		}

		camera.rotateDegrees(camRot);
		window.begin_frame!false();
		scene3D.bind();
			float distance = camera.distance;
			camera.distance = 0;
			skyUni.projection = camera.vp();
			skyBox.render(skyUni, lights.palette, skyMeshes);
			camera.distance = distance;


			animGlobals.projection = camera.vp();
			anim.update(delta, pInstance);
			anim.render(animGlobals, lights.palette, pInstance);

			sGlobals.projection = animGlobals.projection;

			sMesh.render(sGlobals, lights.palette, sInstance);
		scene3D.unbind();
		scene3D.render();

		receive(
			(UIReady _) {},
			(UICancel _) {throw new Exception("An error occured in the UI system");}
		);
		if(frame % 2 == 0 || uiFrameTime >= uiFrameRate)
		{
			g_ui.render();
			uiFrameTime = 0;
		}
		else
		{
			g_ui.render!false();
		}

		time_accum += delta;
		runningMaxDelta_ms = delta_ms > runningMaxDelta_ms ? delta_ms : runningMaxDelta_ms;
		accumDelta_ms += delta_ms;

		g_oxygen -= g_oxygenDrain*delta;

		if(time_accum >= 2.75)
		{
			g_frameTime = format(debugFormat, delta_ms, runningMaxDelta_ms, accumDelta_ms/runningFrame);
			g_oxygenText = format(oxygenFormat, g_oxygen);

			runningMaxDelta_ms = delta_ms;
			accumDelta_ms = delta_ms;
			runningFrame = 1;
			time_accum = 0;
		}

		g_uiInput.apply(input);
		uiThread.send(UIEvents(delta, window.state, window.getSize()));

		window.end_frame();

		debug frame_log.writefln("%f\t%f\t%f", delta_ms, runningMaxDelta_ms, accumDelta_ms/runningFrame);
		frame ++;
		runningFrame ++;
	}

	uiThread.send(UICancel());
	auto _ = receiveOnly!UIReady();

	debug writeln("Game closing");
	return 0;
}