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
import lanlib.file.gltf2;
import lanlib.file.lgbt;
import lanlib.file.uidl;
import lanlib.util.memory;

import logic.input;

import render.gl;
import render.material;
import render.mesh;
import render.window;

import test.loading;

import ui;

enum atlasTest = false;

int main()
{
	ushort screen_w = 720;
	ushort screen_h = 512;
	
	FreeImage_Initialise(true);
	scope(exit) FreeImage_DeInitialise();

	Window ww = Window(screen_w, screen_h, "Lantana Editor");
	Input ii = Input();
	
	auto mm = BaseRegion(MAX_MEMORY);

	UIRenderer ui = new UIRenderer(ww.getSize());

	ww.grab_mouse(false);

	SpriteId needlefulPNG = ui.loadSprite("data/test/needleful.png");
	SpriteId upclickSprite = ui.loadSprite("data/test/ui_sprites/upclick.png");

	FontId testFont = ui.loadFont("data/ui/fonts/averia/Averia-Regular.ttf", 24);

	auto title = new TextBox(ui, testFont, "Lantana Editor", true);
	bool pressed = false;

	ui.setRootWidget(new HodgePodge([
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
			title,
			vec2(0.27, 1-0.048),
			vec2(0, 1)
		),
		new Anchor (
			new Button(
				ui,
				new Padding(
					new TextBox(ui, testFont, "Press Me!"),
					12, 18
				),
				ui.loadSprite("data/test/ui_sprites/test-9patch.png"),
				(Widget source) 
				{
					pressed = !pressed;
					if(pressed)
					{
						title.setText("Pressed the button!");
					}
					else
					{
						title.setText("Lantana Editor");
					}
				},
			),
			vec2(0, 0.9),
			vec2(0, 1)
		),
	]));

	while(!ww.state[WindowState.CLOSED])
	{
		ww.pollEvents(&ii);

		if(ww.state[WindowState.RESIZED])
		{
			ui.setSize(ww.getSize());
		}
		static if(atlasTest)
		{
			ww.begin_frame();
			ui.debugRender();
			ww.end_frame();
		}
		else
		{
			ui.update(0.016f, &ii);
			ww.begin_frame();
			ui.render();
			ww.end_frame();
		}
	}
	
	return 0;
}