// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

import core.memory;
import std.format;
import std.math;
import std.stdio;

import lanlib.gltf2;
import lanlib.math.projection;
import lanlib.math.transform;
import lanlib.types;
import lanlib.util.files;
import lanlib.util.memory;
import lanlib.util.sdl;

import gl3n.linalg;

import logic.grid;
import logic.input;
import logic.player;
import logic.scenes;

import render.camera;
import render.lights;
import render.material;
import render.mesh;
import render.textures;
import test.scenes;

import ui;

enum MAX_MEMORY = 1024*1024*16;

enum cam_speed = 8;

float g_timescale = 1;

struct GameManager
{
	private BaseRegion mainMem;
	private SubRegion sceneMem;
	OwnedRef!Input input;
	OwnedRef!StaticMeshSystem staticSystem;
	OwnedRef!AnimatedMeshSystem animSystem;
	OwnedRef!Scene scene;

	@disable this();

	this(size_t p_memCapacity)
	{
		mainMem = BaseRegion(p_memCapacity);

		input = mainMem.make!Input();

		staticSystem = mainMem.make!StaticMeshSystem(loadMaterial("data/shaders/worldspace3d.vert", "data/shaders/material3d.frag"));
		animSystem = mainMem.make!AnimatedMeshSystem(loadMaterial("data/shaders/animated3d.vert", "data/shaders/material3d.frag"));

		sceneMem = mainMem.provideRemainder();
	}

	void loadScene(SceneLoader p_scene, bool p_preserveCamRotation = false)
	{
		staticSystem.clearMeshes();
		animSystem.clearMeshes();

		sceneMem.wipe();

		if(p_preserveCamRotation)
		{
			vec2 rotation = scene.camera.rot;
			scene = sceneMem.make!Scene(p_scene, staticSystem, animSystem, sceneMem);
			scene.camera.rot = rotation;
		}
		else
		{
			scene = sceneMem.make!Scene(p_scene, staticSystem, animSystem, sceneMem);
		}
	}
}

int main()
{
	// Loader test
	storeBinary("data/scenes/test1.lnt", testScene());
	storeBinary("data/scenes/test2.lnt", testScene2());
	// Testing done.

	Window window = Window(720, 512, "Axe manor");
	GameManager game = GameManager(MAX_MEMORY);
	// Testing SceneLoader format
	game.loadScene(loadBinary!SceneLoader("data/scenes/test1.lnt"));
	debug writeln("Running Axe Manor in debug mode!");

	UIRenderer ui = new UIRenderer(window.getSize());

	SpriteId upclickSprite = ui.loadSprite("data/test/ui_sprites/upclick.png");
	FontId debugFont = ui.loadFont("data/fonts/averia/Averia-Regular.ttf", 20);
	string debugFormat = ": %6.3f\n: %6.3f\n: %6.3f";

	TextBox frameTime = new TextBox(ui, debugFont, debugFormat, true);
	ui.setRootWidget(new HodgePodge([
	new Anchor(
		new HBox([
				new ImageBox(ui, upclickSprite),
				new TextBox(ui, debugFont, "Frame Time\nMax\nAverage"), 
				frameTime
			], 5),
			vec2(0.99, 0.99),
			vec2(1, 1)
		)
	]));


	uint frame = 0;
	int[2] wsize = window.get_dimensions();

	debug writeln("Beginning game loop");
	stdout.flush();

	float maxDelta_ms = -1;
	float runningMaxDelta_ms = -1;
	float accumDelta_ms = 0;
	float runningFrame = 0;
	bool paused;

	while(!window.state[WindowState.CLOSED])
	{
		float delta_ms = window.delta_ms();
		float delta = g_timescale*delta_ms/1000.0;
		runningMaxDelta_ms = delta_ms > runningMaxDelta_ms ? delta_ms : runningMaxDelta_ms;
		
		accumDelta_ms += delta_ms;
		if(frame % 256 == 0)
		{
			maxDelta_ms = runningMaxDelta_ms;
			runningMaxDelta_ms = -1;
			frameTime.setText(format(debugFormat, delta_ms, maxDelta_ms, accumDelta_ms/runningFrame));
			runningFrame = 1;
			accumDelta_ms = 0;
			if(paused)
			{	
				// Try garbage collecting while paused
				GC.collect();
			}
		}
		runningFrame ++;
	
		window.pollEvents(game.input);

		if(window.state[WindowState.RESIZED])
		{
			wsize = window.get_dimensions();
			game.scene.camera.set_projection(
				Projection(cast(float)wsize[0]/wsize[1], 60, DEFAULT_NEAR_PLANE, DEFAULT_FAR_PLANE)
			);
			ui.setSize(window.getSize());
		}

		if(game.input.is_just_pressed(Input.Action.PAUSE))
		{
			paused = !paused;
			window.grab_mouse(!paused);
		}
		if(game.input.is_just_pressed(Input.Action.DEBUG_LOADLEVEL))
		{
			if(game.scene.nextScene != "")
			{
				game.loadScene(loadBinary!SceneLoader(game.scene.nextScene), true);
				game.scene.camera.set_projection(
					Projection(cast(float)wsize[0]/wsize[1], 60, DEFAULT_NEAR_PLANE, DEFAULT_FAR_PLANE)
				);
			}
			else
			{
				writeln("No scene to go to!");
			}
		}

		if(!paused)
		{
			game.scene.camera.rot.x += game.input.mouse_movement.x*delta*60;
			float next_rot = game.scene.camera.rot.y + game.input.mouse_movement.y*delta*60;
			if(abs(next_rot) < 90)
			{
				game.scene.camera.rot.y = next_rot;
			}
			
			game.scene.update(game.input, delta);

			game.animSystem.update(delta, game.scene.animMeshes);
		}
		ui.update(delta);

		window.begin_frame();
		mat4 vp = game.scene.camera.vp();
		game.animSystem.render(vp, game.scene.worldLight, game.scene.animMeshes);
		game.staticSystem.render(vp, game.scene.worldLight, game.scene.staticMeshes);
		ui.render();

		window.end_frame();
		frame ++;

	}
	debug writeln("Game closing");
	return 0;
}