// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.main;

import core.memory;
import std.concurrency;
import std.format;
import std.math;
import std.stdio;

import audio;
import game.dialog;
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

final class DialogButton : Button
{
	Dialog dialog;
	
	public this(UIRenderer p_renderer, Dialog.Callback p_callback)
	{
		visible = false;

		super(p_renderer, new TextBox(p_renderer.style.defaultFont, "", 128), 
			(Widget w)
			{
				p_callback(this.dialog);
			});
	}

	public void setDialog(Dialog p_dialog)
	{
		dialog = p_dialog;
		(cast(TextBox)getChild()).setText(p_dialog.message);
	}

	public override string toString()
	{
		import std.format;
		if(!dialog)
		{
			return format("DialogButton @[%x], <empty>", cast(void*)this);
		}
		return format("DialogButton @[%x], %s, %s", cast(void*)this, dialog.message, dialog.responses);
	}
}

struct DialogState
{
	Dialog current;
	DialogButton[] buttons;
	VBox messageBox;
	float timer;
}

struct UIReady{}
struct UICancel{}

struct UIEvents
{
	float delta;
	Input input;
	Bitfield!WindowState window;
	RealSize size;

	this(float p_delta, Input p_input, Bitfield!WindowState p_window, RealSize p_size)
	{
		delta = p_delta;
		input = p_input;
		window = p_window;
		size = p_size;
	}
}

__gshared UIRenderer g_ui;
__gshared string g_frameTime;

void uiMain()
{
	with(g_ui.style)
	{
		button.normal = g_ui.loadSprite("data/ui/sprites/rect-interact-normal.png");
		button.pressed = g_ui.loadSprite("data/ui/sprites/rect-interact-clicked.png");
		button.focused = g_ui.loadSprite("data/ui/sprites/rect-interact-focus.png");
		button.mesh = new PatchRectStyle(button.normal, Pad(6));
		button.pad = Pad(8, 12);
		
		panel.sprite = g_ui.addSinglePixel(color(196, 247, 255));
		panel.mesh = new SpriteQuadStyle(panel.sprite);

		scrollbar.width = 20;
		scrollbar.trough.sprite = g_ui.addSinglePixel(color(0, 148, 255, 128));
		scrollbar.trough.mesh = new SpriteQuadStyle(scrollbar.trough.sprite);
		scrollbar.upArrow = g_ui.loadSprite("data/ui/sprites/arrow-up.png");
		scrollbar.downArrow = g_ui.loadSprite("data/ui/sprites/arrow-down.png");

		defaultFont = g_ui.loadFont("data/ui/fonts/averia/Averia-Regular.ttf", 20);
	}

	/// BEGIN - Dialog initialization
	DialogState ds;

	bool showDialog = true;
	ds.buttons.reserve(8);

	void dialogCallback(Dialog p_dialog)
	{
		assert(p_dialog.responses.length <= ds.buttons.length);
		ds.current = p_dialog;

		ds.messageBox.addChild(new TextBox(g_ui.style.defaultFont, p_dialog.message));

		foreach(i, resp; p_dialog.responses)
		{
			ds.buttons[i].setVisible(true);
			ds.buttons[i].setDialog(resp);
		}

		for(ulong i = p_dialog.responses.length; i < ds.buttons.length; i++)
		{
			ds.buttons[i].setVisible(false);
		}
		ds.timer = 0;
		showDialog = false;
	}

	for(int i = 0; i < 8; i++)
	{
		ds.buttons ~= new DialogButton(g_ui, &dialogCallback);
	}

	Widget[] tmp_widgets;
	tmp_widgets.reserve(ds.buttons.length);

	foreach(button; ds.buttons)
	{
		tmp_widgets ~= button;
	}

	VBox dialogbox = new VBox(tmp_widgets, 0, true);

	ds.messageBox = new VBox([new ImageBox(g_ui, g_ui.loadSprite("data/test/needleful.png"))], 18);
	Dialog currentDialog = testDialog();
	Widget dialogWidget = new Padding(
		dialogbox, 
		Pad(8), 
		g_ui.style.panel.mesh.create(g_ui));
	/// END - Dialog initialization

	SpriteId upclickSprite = g_ui.loadSprite("data/test/ui_sprites/upclick.png");

	TextBox frameTime = new TextBox(g_ui.style.defaultFont, "", 64);

	Modal uiModal = new Modal([
		// Pause menu
		new AnchoredBox([
			g_ui.style.panel.mesh.create(g_ui),
			new Padding(
				new Scrolled(new Padding(ds.messageBox, Pad(12)), 0),
				Pad(8)),
			new Positioned(
				dialogWidget,
				vec2(1, 0),
				vec2(0, 0))
			],

			vec2(0.02,0.02),
			vec2(0.2, .98),
		).withBounds(Bounds(450, double.infinity), Bounds.none),

		new HodgePodge([]),
	]);

	g_ui.setRootWidget(
		new HodgePodge([
			uiModal,
	 		new Anchor(
				new HBox([
					new TextBox(g_ui.style.defaultFont, "Frame Time\nMax\nAverage"), 
					frameTime
				], 5),
				vec2(0.99, 0.99),
				vec2(1, 1)
		)]));

	// Needs to be run after initialization
	dialogCallback(currentDialog);

	uiModal.setMode(1);

	ownerTid.send(UIReady());
	bool paused = false;
	void processEvents(UIEvents events)
	{
		if(events.window[WindowState.RESIZED])
		{
			g_ui.setSize(events.size);
		}

		if(events.input.is_just_pressed(Input.Action.PAUSE))
		{
			paused = !paused;
			if(paused)
			{
				uiModal.setMode(0);
			}
			else
			{
				uiModal.setMode(1);
			}
		}

		if((ds.timer += events.delta) >= ds.current.pauseTime)
		{
			showDialog = true;
		}

		dialogWidget.setVisible(showDialog);
		if(showDialog)
		{
			ds.messageBox.addChild(
				new HBox([
					new ImageBox(g_ui, upclickSprite),
					new TextBox(g_ui.style.defaultFont, format("Mambo number %u", ds.messageBox.getChildren().length))
				]));
		}

		frameTime.setText(g_frameTime);
		g_ui.update(events.delta, &events.input);
	}

	bool shouldRun = true;
	while(shouldRun)
	{
		receive(
			&processEvents,
			(UICancel _)
			{
				shouldRun = false;
			});

		ownerTid.send(UIReady());
	}
}

version(lantana_game)
int main()
{
	Window window = Window(1280, 720, "Texting my Boyfriend while Dying in Space");
	RealSize ws = window.getSize();
	g_ui = new UIRenderer(ws);

	auto uiThread = spawn(&uiMain);

	AudioManager audio = AudioManager(16);
	audio.startMusic("data/audio/music/forest_floor.ogg", 4000);

	debug writeln("Beginning game loop");
	stdout.flush();

	float runningMaxDelta_ms = -1;
	float accumDelta_ms = 0;
	bool paused = false;

	Input input = Input();
	uint frame = 0;

	string debugFormat = ": %6.3f\n: %6.3f\n: %6.3f";

	receiveOnly!UIReady();
	g_ui.initialize();

	float delta = 0.001f;
	uiThread.send(UIEvents(delta, input, window.state, window.getSize()));

	while(!window.state[WindowState.CLOSED])
	{
		float delta_ms = window.delta_ms();
		delta = g_timescale*delta_ms/1000.0;
		runningMaxDelta_ms = delta_ms > runningMaxDelta_ms ? delta_ms : runningMaxDelta_ms;
		accumDelta_ms += delta_ms;

		if(frame % 256 == 0)
		{
			g_frameTime = format(debugFormat, delta_ms, runningMaxDelta_ms, accumDelta_ms/256);

			runningMaxDelta_ms = -1;
			accumDelta_ms = 0;
			if(paused)
			{
				GC.collect();
			}
		}
	
		window.pollEvents(&input);


		if(input.is_just_pressed(Input.Action.PAUSE))
		{
			paused = !paused;
			window.grab_mouse(!paused);
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

		UIReady _ = receiveOnly!UIReady();
		window.begin_frame();
		g_ui.render();
		uiThread.send(UIEvents(delta, input, window.state, window.getSize()));

		window.end_frame();
		frame ++;
	}
	debug writeln("Game closing");
	return 0;
}