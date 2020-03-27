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

import editor.graph;
import game.dialog;

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

	Window ww = Window(screen_w, screen_h, "Dialog Editor");
	Input ii = Input();
	
	auto mm = BaseRegion(MAX_MEMORY);

	UIRenderer ui = new UIRenderer(ww.getSize());
	with(ui.style)
	{
		button.normal = ui.loadSprite("data/ui/sprites/rect-interact-normal.png");
		button.pressed = ui.loadSprite("data/ui/sprites/rect-interact-clicked.png");
		button.focused = ui.loadSprite("data/ui/sprites/rect-interact-focus.png");
		button.mesh = new PatchRectStyle(button.normal, Pad(6));
		button.pad = Pad(8);
		
		panel.sprite = ui.addSinglePixel(color(196, 247, 255));
		panel.mesh = new SpriteQuadStyle(panel.sprite);

		scrollbar.width = 20;
		scrollbar.trough.sprite = ui.addSinglePixel(color(0, 148, 255, 128));
		scrollbar.trough.mesh = new SpriteQuadStyle(scrollbar.trough.sprite);
		scrollbar.upArrow = ui.loadSprite("data/ui/sprites/arrow-up.png");
		scrollbar.downArrow = ui.loadSprite("data/ui/sprites/arrow-down.png");

		defaultFont = ui.loadFont("data/ui/fonts/ClearSans.ttf", 16);
		defaultFontColor = vec3(0.0, 0.583, 1);

		textInput.cursor = ui.addSinglePixel(AlphaColor(255));
		textInput.focused = vec3(1, 0.5, 0.9);
		textInput.normal = vec3(0.9, 0.5, 0.4);

		line = ui.addSinglePixel(color(255, 255, 255, 120));
	}

	ww.grab_mouse(false);

	SpriteId needlefulPNG = ui.loadSprite("data/test/needleful.png");
	SpriteId upclickSprite = ui.loadSprite("data/test/ui_sprites/upclick.png");

	auto title = new TextBox("Lantana Editor", 64);
	bool pressed = false;

	TextInput testText = new TextInput(256, "Hullo, love!");

	Widget[] nodes;

	string start_;
	auto dmap = loadDialog("data/dialog_edit.sdl", start_);
	Dialog start = dmap[start_];
	writeln("start: ", start.getTag());

	DialogNode[Dialog] nodeMap;

	foreach(dialog; dmap)
	{
		auto node = new DialogNode(ui, dialog);
		nodes ~= node;
		nodeMap[dialog] = node;
	}

	foreach(node; nodeMap)
	{	
		foreach(response; node.getDialog().responses)
		{
			node.addResponse(nodeMap[response]);
		}
	}

	auto panned = new Panned(nodes);
	DialogNode.parent = panned.container;
	ui.setRootWidget(panned);

	ui.initialize();

	int frame = 0;
	SDL_StartTextInput();
	while(!ww.state[WindowState.CLOSED])
	{
		float delta = ww.delta_ms/1000.0;
		frame ++;
		ww.pollEvents(&ii);

		if(ww.state[WindowState.RESIZED])
		{
			ui.setSize(ww.getSize());
		}

		if(ii.keyboard.isJustPressed(SDL_SCANCODE_S) && ii.keyboard.isPressed(SDL_SCANCODE_LCTRL))
		{
			foreach(node; DialogNode.nodes)
			{
				node.updateDialog();
			}
			storeDialog("data/dialog_edit.sdl", start);
		}

		ui.updateInteraction(delta, &ii);
		DialogNode.mousePosition = ii.mouse_position;
		ui.updateLayout();

		ww.begin_frame();
		ui.render();
		ww.end_frame();
	}
	SDL_StopTextInput();
	
	return 0;
}