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
import lanlib.util.memory;
import lanlib.util.sdl;

import logic.input;

import render.material;
import render.mesh;

import ui;

enum atlas_test = false;

int main()
{
	ushort screen_w = 720;
	ushort screen_h = 512;
	
	FreeImage_Initialise(true);
	scope(exit) FreeImage_DeInitialise();

	SDLWindow ww = SDLWindow(screen_w, screen_h, "Lantana Editor");
	Input ii = Input();
	ILanAllocator mm = new LanRegion(1024*1024*16, new SysMemManager());
	UIRenderer ui = new UIRenderer(ww.getSize(), mm);

	ww.grab_mouse(false);

	SpriteId needlefulPNG = ui.loadSprite("data/test/needleful.png");
	SpriteId upclickSprite = ui.loadSprite("data/test/ui_sprites/upclick.png");

	FontId testFont = ui.loadFont("data/fonts/averia/Averia-Regular.ttf", 24);
	TextBox frameTime = new TextBox(ui, testFont, "Frame Time Goes Here");

	ui.setRootWidget(new HodgePodge([
		// various tests for Anchor, ImageBox, and TextBox
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
		),
		new Anchor(
			frameTime,
			vec2(0.27, 1-0.048),
			vec2(0, 1)
		)
	]));

	ui.update(0.016f);
	while(!ww.state[WindowState.CLOSED])
	{
		ww.poll_events(ii);

		if(ww.state[WindowState.RESIZED])
		{
			ui.setSize(ww.getSize());
		}
		static if(atlas_test)
		{
			ww.begin_frame();
			ui.debugRender();
			ww.end_frame();
		}
		else
		{
			ui.update(0.016f);
			ww.begin_frame();
			ui.render();
			ww.end_frame();
		}
	}
	
	return 0;
}