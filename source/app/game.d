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

	Window window = Window(1280, 720, "Texting my Boyfriend while Dying in Space");
	RealSize ws = window.getSize();

	AudioManager audio = AudioManager(32);
	//audio.startMusic("data/audio/music/forest_floor.ogg", 4000);

	UIRenderer ui = new UIRenderer(window.getSize());
	with(ui.style)
	{
		button.normal = ui.loadSprite("data/ui/sprites/rect-interact-normal.png");
		button.pressed = ui.loadSprite("data/ui/sprites/rect-interact-clicked.png");
		button.mesh = new SpriteQuad(button.normal);

		panel.sprite = ui.addSinglePixel(color(196, 247, 255));
		panel.mesh = new SpriteQuad(panel.sprite);

		scrollbar.width = 20;
		scrollbar.trough.sprite = ui.addSinglePixel(color(0, 148, 255, 128));
		scrollbar.trough.mesh = new SpriteQuad(scrollbar.trough.sprite);
		scrollbar.upArrow = ui.loadSprite("data/ui/sprites/arrow-up.png");
		scrollbar.downArrow = ui.loadSprite("data/ui/sprites/arrow-down.png");

		defaultFont = ui.loadFont("data/ui/fonts/averia/Averia-Regular.ttf", 20);
	}

	SpriteId upclickSprite = ui.loadSprite("data/test/ui_sprites/upclick.png");
	SpriteId nful = ui.loadSprite("data/test/needleful.png");
	string debugFormat = ": %6.3f\n: %6.3f\n: %6.3f";

	TextBox frameTime = new TextBox(ui.style.defaultFont, debugFormat, true);

	VBox dialog = new VBox([
		new TextBox(ui.style.defaultFont, "Hello!"),
		new ImageBox(ui, nful),
		new ImageBox(ui, nful),
		new ImageBox(ui, "data/test/ui_sprites/upclick.png"),
		new ImageBox(ui, nful),
	], 18);

	Modal uiModal = new Modal([
		// Pause menu
		new AnchoredBox([
			new ImageBox(ui, ui.style.panel.sprite),
			new Padding(new Scrolled(dialog, 0), 18),
		],
		vec2(0.02,0.02), vec2(0.2, .98)
		).withBounds(Bounds(450, double.infinity), Bounds.none),

		// Debug Text
		new Anchor(
			new HBox([
				new TextBox(ui.style.defaultFont, "Frame Time\nMax\nAverage"), 
				frameTime
			], 5),
			vec2(0.99, 0.99),
			vec2(1, 1)
		)
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

	Input input = Input();

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
	
		window.pollEvents(&input);

		if(window.state[WindowState.RESIZED])
		{
			ws = window.getSize();
			ui.setSize(window.getSize());
		}

		if(input.is_just_pressed(Input.Action.PAUSE))
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

		if(!paused)
		{
			//game.scene.camera.rot.x += game.input.mouse_movement.x*delta*60;
			//float next_rot = game.scene.camera.rot.y + game.input.mouse_movement.y*delta*60;
			//if(abs(next_rot) < 90)
			//{
			//	game.scene.camera.rot.y = next_rot;
			//}
			
			//game.scene.update(game.input, delta);

			//game.animSystem.update(delta, game.scene.animMeshes);
		}
		ui.update(delta, &input);

		window.begin_frame();
		ui.render();

		window.end_frame();
		frame ++;

	}
	debug writeln("Game closing");
	return 0;
}