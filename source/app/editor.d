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
	SpriteId uiSprite = ui.loadSprite("data/test/ui_sprites/upclick.png");

	ui.root = new HodgePodge([
		new ImageBox(ui, needlefulPNG),
		new ImageBox(ui, needlefulPNG),
		new ImageBox(ui, uiSprite)
	]);

	ui.update(0f);
	ww.begin_frame();
	ui.debugRender();
	ww.end_frame();

	while(!ww.state[WindowState.CLOSED])
	{
		ww.poll_events(ii);
	}
	
	return 0;
}