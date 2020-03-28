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

import audio;
import game.dialog;
import game.skybox;
import game.ui;
import lanlib.file.gltf2;
import lanlib.math;
import lanlib.types;
import lanlib.file.lgbt;
import lanlib.util.memory;

import gl3n.linalg;

import logic;
import render;

import ui;

enum MAX_MEMORY = 1024*1024*64;
enum cam_speed = 1;

float timescale = 1;
float oxygen = 21.2;
float oxygenDrain = 0.027;

version(lantana_game)
int main()
{
	Window window = Window(1280, 720, "Texting my Boyfriend while Dying in Space");
	RealSize ws = window.getSize();
	g_ui = new UIRenderer(ws);

	Input input = Input();
	g_uiInput = new Input(input);
	auto uiThread = spawn(&uiMain);

	AudioManager audio = AudioManager(16);
	audio.startMusic("data/audio/music/floating-full.ogg", 0);

	auto mainMem = BaseRegion(MAX_MEMORY);
	auto camera = LongRangeOrbitalCamera(vec3(0), cast(float)ws.width/ws.height, 60, vec2(20, 0));
	camera.target = vec3(0);
	camera.distance = 5;

	auto skyBox = SkyMesh.System("data/shaders/skybox.vert", "data/shaders/skybox.frag");
	skyBox.meshes = mainMem.makeOwnedList!(SkyMesh.Mesh)(1);
	auto sky = skyBox.loadMesh("data/meshes/skybox.glb", mainMem);
	SkyMesh.Instance[] skyMeshes = mainMem.makeList!(SkyMesh.Instance)(1);
	skyMeshes[0] = SkyMesh.Instance(sky, Transform(0.5));

	SkyMesh.Uniforms.global skyUni;
	skyUni.gamma = 1.8;


	auto anim = AnimMesh.System("data/shaders/animated3d.vert", "data/shaders/material3d.frag");
	anim.meshes = mainMem.makeOwnedList!(AnimMesh.Mesh)(1);

	AnimMesh.Uniforms.global animGlobals;
	animGlobals.light_direction = vec3(-0.1,-0.3,0.9);
	animGlobals.light_bias = 0.0;
	animGlobals.area_ceiling = -1;
	animGlobals.area_span = 3;
	animGlobals.gamma = 1;
	animGlobals.nearPlane = camera.nearPlane;
	animGlobals.farPlane = camera.farPlane;

	auto playerMesh = anim.loadMesh("data/meshes/kitty-astronaut.glb", mainMem);
	auto pInstance = mainMem.makeList!(AnimMesh.Instance)(1);
	pInstance[0] = AnimMesh.Instance(playerMesh, Transform(1, vec3(0, 0, 0), vec3(0, -40, 180)), mainMem);
	pInstance[0].play("Idle", true);


	auto sMesh = StaticMesh.System("data/shaders/worldspace3d.vert", "data/shaders/material3d.frag");
	sMesh.meshes = mainMem.makeOwnedList!(StaticMesh.Mesh)(1);

	StaticMesh.Uniforms.global sGlobals;
	sGlobals.light_direction = animGlobals.light_direction;
	sGlobals.light_bias = animGlobals.light_bias;
	sGlobals.area_span = 15;
	sGlobals.gamma = animGlobals.gamma;
	sGlobals.nearPlane = camera.nearPlane;
	sGlobals.farPlane = camera.farPlane;

	auto shipMesh = sMesh.loadMesh("data/meshes/ship.glb", mainMem);
	auto sInstance = mainMem.makeList!(StaticMesh.Instance)(1);
	sInstance[0] = StaticMesh.Instance(shipMesh, Transform(1, vec3(10, 25, -30), vec3(12, 143, -90)));
	vec3 shipVel = vec3(.3, .6, -1.2);

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

	int runningFrame = 1;
	float time_accum = 0;
	g_oxygenText = format(oxygenFormat, oxygen);
	while(!window.state[WindowState.CLOSED])
	{
		float delta_ms = window.delta_ms();
		delta = timescale*delta_ms/1000.0;
	
		window.pollEvents(&input);

		if(window.state[WindowState.RESIZED])
		{
			ws = window.getSize();
			camera.setProjection(cast(float)ws.width/ws.height, 60);
		}

		if(input.keyboard.isJustPressed(SDL_SCANCODE_TAB))
		{
			paused = !paused;
			window.grab_mouse(!paused);
		}

		if(!paused)
		{
			velCamRot += input.mouse_movement*delta*accelCamRot;
		}
		velCamRot *= dampCamRot;
		camera.rotateDegrees(velCamRot*cam_speed*delta);

		window.begin_frame!false();

			float distance = camera.distance;
			camera.distance = 0;
			skyUni.projection = camera.vp();
			skyBox.render(skyUni, lights.palette, skyMeshes);
			camera.distance = distance;


			animGlobals.projection = camera.vp();
			pInstance[0].transform.rotate_degrees(-0.1*delta, 1.2*delta, 0.71*delta);
			anim.update(delta, pInstance);
			anim.render(animGlobals, lights.palette, pInstance);


			sGlobals.projection = animGlobals.projection;
			sGlobals.area_ceiling = sInstance[0].transform._position.y;
			sInstance[0].transform.rotate_degrees(2*delta, -0.1*delta, -2.5*delta);
			sInstance[0].transform.translate(delta*shipVel);

			sMesh.render(sGlobals, lights.palette, sInstance);


			UIReady _ = receiveOnly!UIReady();
			g_ui.render();

			time_accum += delta;
			runningMaxDelta_ms = delta_ms > runningMaxDelta_ms ? delta_ms : runningMaxDelta_ms;
			accumDelta_ms += delta_ms;

			oxygen -= oxygenDrain*delta;

			if(time_accum >= 2.75)
			{
				g_frameTime = format(debugFormat, delta_ms, runningMaxDelta_ms, accumDelta_ms/runningFrame);
				g_oxygenText = format(oxygenFormat, oxygen);

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