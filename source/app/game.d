// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

import core.memory;
import std.format;
import std.math;
import std.stdio;

import audio;
import lanlib.file.gltf2;
import lanlib.math;
import lanlib.types;
import lanlib.file.lgbt;
import lanlib.util.memory;

import gl3n.linalg;

import logic;
import render;
import test.scenes;

import ui;

enum cam_speed = 8;

float g_timescale = 1;

int main()
{
	// Store test scenes
	binaryStore("data/scenes/test1.lgbt", testScene());
	binaryStore("data/scenes/test2.lgbt", testScene2());

	Window window = Window(1280, 720, "Axe manor");
	GameManager game = GameManager(MAX_MEMORY,"data/scenes/test1.lgbt");
	RealSize ws = window.getSize();
	
	game.scene.camera.set_projection(
		Projection(cast(float)ws.width/ws.height, 60, DEFAULT_NEAR_PLANE, DEFAULT_FAR_PLANE)
	);

	AudioManager audio = AudioManager(32);
	//audio.startMusic("data/audio/music/forest_floor.ogg", 4000);

	// Testing SceneLoader format
	debug writeln("Running Axe Manor in debug mode!");

	UIRenderer ui = new UIRenderer(window.getSize());

	SpriteId upclickSprite = ui.loadSprite("data/test/ui_sprites/upclick.png");
	SpriteId nful = ui.loadSprite("data/test/needleful.png");

	FontId debugFont = ui.loadFont("data/ui/fonts/averia/Averia-Regular.ttf", 20);
	string debugFormat = ": %6.3f\n: %6.3f\n: %6.3f";

	TextBox frameTime = new TextBox(debugFont, debugFormat, true);

	Modal uiModal = new Modal([
		new AnchoredBox([
			new ImageBox(ui, color(200, 120, 60, 255), RealSize(2)),
			new Padding(
				new Scrolled(
				new VBox([
					new TextBox(debugFont, "Hello!"),
					new ImageBox(ui, nful),
					new ImageBox(ui, nful),
					new ImageBox(ui, "data/test/ui_sprites/upclick.png"),
					new ImageBox(ui, nful),
				]), 1),
			18),
			new Positioned(
				new ImageBox(ui, nful).withBounds(Bounds(ws.width/8), Bounds(ws.width/8)),
				vec2(1, 0.5), vec2(0.33, 0.5)
		)],
		vec2(0.02,0.02), vec2(0.2, .98)
		).withBounds(Bounds(450, double.infinity), Bounds.none),

		new HodgePodge([
			new Anchor(
				new HBox([
					new TextBox(debugFont, "Frame Time\nMax\nAverage"), 
					frameTime
				], 5),
				vec2(0.99, 0.99),
				vec2(1, 1)
			)
		])
	]);

	ui.setRootWidget(uiModal);

	uiModal.setMode(1);

	uint frame = 0;

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
			ws = window.getSize();
			game.scene.camera.set_projection(
				Projection(cast(float)ws.width/ws.height, 60, DEFAULT_NEAR_PLANE, DEFAULT_FAR_PLANE)
			);
			ui.setSize(window.getSize());
		}

		if(game.input.is_just_pressed(Input.Action.PAUSE))
		{
			paused = !paused;
			window.grab_mouse(!paused);
			if(paused)
			{
				uiModal.setMode(0);
			}
			else
			{
				uiModal.setMode(1);
			}
		}
		if(game.input.is_just_pressed(Input.Action.DEBUG_LOADLEVEL))
		{
			if(game.scene.nextScene != "")
			{
				game.loadScene(game.scene.nextScene, true);
				game.scene.camera.set_projection(
					Projection(cast(float)ws.width/ws.height, 60, DEFAULT_NEAR_PLANE, DEFAULT_FAR_PLANE)
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
		ui.update(delta, game.input);

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