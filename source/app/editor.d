// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

import std.format;
import std.stdio;

import deimos.freeimage;
import derelict.freetype;
import derelict.sdl2.sdl;

import gl3n.linalg;

import lanlib.types;
import lanlib.util.gl;
import lanlib.util.sdl;

import logic.input;

import render.material;
import render.mesh;

import ui;

int main()
{
	ushort screen_w = 720;
	ushort screen_h = 512;
	
	FreeImage_Initialise(true);
	scope(exit) FreeImage_DeInitialise();

	SDLWindow ww = SDLWindow(screen_w, screen_h, "Lantana Editor");
	Input ii = Input();
	UIRenderer ui = new UIRenderer(ww.getSize());

	ww.grab_mouse(false);

	SpriteId needlefulPNG = ui.loadSprite("data/test/needleful.png");
	SpriteId upclickSprite = ui.loadSprite("data/test/ui_sprites/upclick.png");

	ui.setRootWidget(new HodgePodge([
		// various tests for Anchor and ImageBox
		new Anchor(
			new ImageBox(ui, upclickSprite),
			vec2(0.5,0.6),
			vec2(0.5,0)
		),
		new Anchor(
			new ImageBox(ui, needlefulPNG),
			vec2(0, 0.9),
			vec2(0, 1)
		),
		new Anchor(
			new ImageBox(ui, upclickSprite),
			vec2(1,1), vec2(1,1)
		),
		new Anchor(
			new ImageBox(ui, needlefulPNG),
			vec2(0.027, 0.048),
			vec2(0, 0)
		)
	]));

	while(!ww.state[WindowState.CLOSED])
	{
		ww.poll_events(ii);

		if(ww.state[WindowState.RESIZED])
		{
			ui.setSize(ww.getSize());
		}

		ui.update(0.016f);
		ww.begin_frame();
		ui.render();
		ww.end_frame();
	}
	
	return 0;
}