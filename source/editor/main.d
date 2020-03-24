// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module editor.main;

import std.format;
import std.stdio;

import bindbc.sdl;
import deimos.freeimage;
import derelict.freetype;
import gl3n.linalg;

import lanlib.types;
import lanlib.file.gltf2;
import lanlib.file.lgbt;
import lanlib.util.memory;
import logic.input;
import render.gl;
import render.material;
import render.mesh;
import render.window;
import ui;

enum MAX_MEMORY = 1024*1024*8;

version(lantana_editor)
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
	with(ui.style)
	{
		button.normal = ui.loadSprite("data/ui/sprites/rect-interact-normal.png");
		button.pressed = ui.loadSprite("data/ui/sprites/rect-interact-clicked.png");
		button.focused = ui.loadSprite("data/ui/sprites/rect-interact-focus.png");
		button.mesh = new PatchRectStyle(button.normal, Pad(6));
		button.pad = Pad(8, 8, 12, 12);
		
		panel.sprite = ui.addSinglePixel(color(196, 247, 255));
		panel.mesh = new SpriteQuadStyle(panel.sprite);

		scrollbar.width = 20;
		scrollbar.trough.sprite = ui.addSinglePixel(color(0, 148, 255, 128));
		scrollbar.trough.mesh = new SpriteQuadStyle(scrollbar.trough.sprite);
		scrollbar.upArrow = ui.loadSprite("data/ui/sprites/arrow-up.png");
		scrollbar.downArrow = ui.loadSprite("data/ui/sprites/arrow-down.png");

		defaultFont = ui.loadFont("data/ui/fonts/averia/Averia-Regular.ttf", 20);
		defaultFontColor = vec3(0.0, 0.583, 1);
	}

	ww.grab_mouse(false);

	SpriteId needlefulPNG = ui.loadSprite("data/test/needleful.png");
	SpriteId upclickSprite = ui.loadSprite("data/test/ui_sprites/upclick.png");

	auto title = new TextBox("Lantana Editor", 64);
	bool pressed = false;

	TextInput testText = new TextInput(AlphaColor(255),
				256, "Hullo, love!",
				FontId.invalid, vec3(0.3));

	ui.setRootWidgets([
		new Anchor(
			testText,
			vec2(0.98,0.98), vec2(1,1)
		),
		new Anchor(
			new ImageBox(needlefulPNG),
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
				new TextBox("Press Me!"),
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
			vec2(0.01, 0.9),
			vec2(0, 1)
		),
	]);

	ui.initialize();

	int frame = 0;
	while(!ww.state[WindowState.CLOSED])
	{
		frame ++;
		ww.pollEvents(&ii);

		if(ww.state[WindowState.RESIZED])
		{
			ui.setSize(ww.getSize());
		}

		if(ii.is_just_pressed(Input.Action.LEFT))
		{
			testText.cursorLeft();
		}
		if(ii.is_just_pressed(Input.Action.RIGHT))
		{
			testText.cursorRight();
		}
		if(ii.is_just_pressed(Input.Action.DEBUG1))
		{
			testText.insert(cast(char) ((frame % 52)  + 28));
		}
		if(ii.is_just_pressed(Input.Action.DEBUG2))
		{
			testText.backSpace();
		}

		ui.updateInteraction(&ii);
		ui.updateLayout();

		ww.begin_frame();
		ui.render();
		ww.end_frame();
	}
	
	return 0;
}