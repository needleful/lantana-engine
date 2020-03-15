// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.main;

import core.memory;
import std.concurrency;
import std.format;
import std.math;
import std.stdio;

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

enum cam_speed = 1;

float g_timescale = 1;

enum g_MemoryCapacity = 1024*1024*64;


version(lantana_game)
int main()
{
	Window window = Window(1280, 720, "Texting my Boyfriend while Dying in Space");
	RealSize ws = window.getSize();
	g_ui = new UIRenderer(ws);

	auto uiThread = spawn(&uiMain);

	AudioManager audio = AudioManager(16);
	audio.startMusic("data/audio/music/floating-full.ogg", 0);

	auto mainMem = BaseRegion(g_MemoryCapacity);

	auto sysMesh = AnimMesh.System(loadMaterial("data/shaders/animated3d.vert", "data/shaders/material3d.frag"));
	sysMesh.meshes = mainMem.makeOwnedList!(AnimMesh.Mesh)(1);

	AnimMesh.Uniforms.global globals;
	globals.light_direction = vec3(-0.1,-0.3,0.9);
	globals.light_bias = 0.3;
	globals.area_ceiling = -1;
	globals.area_span = 3;
	globals.gamma = 1;

	auto mesh = sysMesh.loadMesh("data/meshes/kitty-astronaut.glb", mainMem);
	auto instances = mainMem.makeList!(AnimMesh.Instance)(1);
	instances[0] = AnimMesh.Instance(mesh, Transform(1, vec3(0, 0, 0), vec3(0, -40, 180)), mainMem);
	instances[0].play("Idle", true);


	auto skyBox = SkyMesh.System(loadMaterial("data/shaders/skybox.vert", "data/shaders/skybox.frag"));
	skyBox.meshes = mainMem.makeOwnedList!(SkyMesh.Mesh)(1);
	auto sky = skyBox.loadMesh("data/meshes/skybox.glb", mainMem);
	SkyMesh.Instance[] skyMeshes = mainMem.makeList!(SkyMesh.Instance)(1);
	skyMeshes[0].transform = Transform(1);
	skyMeshes[0].mesh = sky;

	SkyMesh.Uniforms.global skyUni;
	skyUni.gamma = 1.8;

	auto camera = OrbitalCamera(vec3(0, -1.2, -5), cast(float)ws.width/ws.height, 60, vec2(20, 0));
	camera.target = vec3(0);
	camera.distance = 5;
	auto lights = LightPalette("data/palettes/skyTest.png", mainMem);

	float runningMaxDelta_ms = -1;
	float accumDelta_ms = 0;
	bool paused = false;

	Input input = Input();
	uint frame = 0;

	//string debugFormat = ": %6.3f\n: %6.3f\n: %6.3f";

	receiveOnly!UIReady();
	g_ui.initialize();

	float delta = 0.001f;
	uiThread.send(UIEvents(delta, input, window.state, window.getSize()));

	vec2 velCamRot = vec2(0);
	float accelCamRot = 60;
	float dampCamRot = 0.99;

	debug
	{
		File frame_log = File("logs/framerate.tsv", "w");
		frame_log.writeln("Frametime\tMax\tAverage");
	}
	int runningFrame = 1;
	while(!window.state[WindowState.CLOSED])
	{
		float delta_ms = window.delta_ms();
		delta = g_timescale*delta_ms/1000.0;
		runningMaxDelta_ms = delta_ms > runningMaxDelta_ms ? delta_ms : runningMaxDelta_ms;
		accumDelta_ms += delta_ms;

		if(frame % 256 == 0)
		{
			//g_frameTime = format(debugFormat, delta_ms, runningMaxDelta_ms, accumDelta_ms/256);

			runningMaxDelta_ms = delta_ms;
			accumDelta_ms = delta_ms;
			runningFrame = 1;
		}
	
		window.pollEvents(&input);

		if(window.state[WindowState.RESIZED])
		{
			ws = window.getSize();
			camera.set_projection(
				Projection(cast(float)ws.width/ws.height, 60, DEFAULT_NEAR_PLANE, DEFAULT_FAR_PLANE)
			);
		}

		if(input.is_just_pressed(Input.Action.PAUSE))
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

		instances[0].transform.rotate_degrees(-0.1*delta, 1.2*delta, 0.71*delta);
		sysMesh.update(delta, instances);

		UIReady _ = receiveOnly!UIReady();
		window.begin_frame();

		float distance = camera.distance;
		camera.distance = 0;

		skyUni.projection = camera.vp();
		skyBox.render(skyUni, lights.palette, skyMeshes);

		camera.distance = distance;
		globals.projection = camera.vp();

		sysMesh.render(globals, lights.palette, instances);
		g_ui.render();

		uiThread.send(UIEvents(delta, input, window.state, window.getSize()));
		window.end_frame();

		debug frame_log.writefln("%f\t%f\t%f", delta_ms, runningMaxDelta_ms, accumDelta_ms/runningFrame);
		frame ++;
		runningFrame ++;
	}
	debug writeln("Game closing");
	return 0;
}