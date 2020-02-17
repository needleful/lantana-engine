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
	Window window = Window(900, 600, "Fun Game: Chit Chat");
	window.grab_mouse(false);

	RealSize ws = window.getSize();
	UIRenderer ui = new UIRenderer(ws);

	FontId defaultFont = ui.loadFont("data/ui/fonts/averia/Averia-Regular.ttf", 24);
	SpriteId nful = ui.loadSprite("data/test/needleful.png");

	ui.setRootWidgets([
		new AnchoredBox([
				new ImageBox(ui, color(200, 120, 60, 255), RealSize(2)),
				new Padding(
					new Scrolled(
					new VBox([
						new TextBox(defaultFont, "Hello!"),
						new ImageBox(ui, nful),
						new ImageBox(ui, nful),
						new ImageBox(ui, "data/test/ui_sprites/upclick.png"),
						new ImageBox(ui, nful),
					])),
				18),
				new Positioned(
					new ImageBox(ui, nful).withBounds(Bounds(ws.width/6), Bounds(ws.width/6)),
					vec2(1, 0.5), vec2(0.33, 0.5)
				),
			],
			vec2(0.02,0.02), vec2(0.2, .98)
		).withBounds(Bounds(450, double.infinity), Bounds.none)
	]);

	Input input = Input();

	uint frame = 0;

	debug writeln("Beginning game loop");
	stdout.flush();

	while(!window.state[WindowState.CLOSED])
	{
		window.pollEvents(&input);
		float delta = window.delta_ms()/1000.0;

		if(window.state[WindowState.RESIZED])
		{
			ui.setSize(window.getSize());
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