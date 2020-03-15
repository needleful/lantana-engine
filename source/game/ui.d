// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.ui;

import core.memory;
import std.concurrency;
import std.format;
import std.math;
import std.stdio;
import std.string: split;

import audio;
import game.dialog;
import game.skybox;
import lanlib.file.gltf2;
import lanlib.math;
import lanlib.types;
import lanlib.file.lgbt;
import lanlib.util.memory;

import gl3n.linalg;

import logic;
import render;

import ui;

static immutable(vec3) kittyColor = vec3(0.8, 0.27, 0.83);
static immutable(vec3) botoColor = vec3(0.2, 0.75, 0.3);

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
		(cast(TextBox)getChild()).setText(p_dialog.message, true);
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

final class Message : HBox
{
	public static FontId font;
	static bool initialized;
	static string fontFile;

	string sender, content;
	vec3 senderColor;

	this(string p_sender, string p_content, vec3 p_color)
	{
		sender = p_sender;
		content = p_content;
		senderColor = p_color;
		super([], 10, Alignment.TOP);
	}

	public override void initialize(UIRenderer p_renderer, UIView p_view)
	{
		children = [
			new TextBox(font, sender, senderColor),
			new TextBox(p_renderer.style.defaultFont, content)
		];
		super.initialize(p_renderer, p_view);
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
__gshared string g_oxygenText;

void uiMain()
{
	with(g_ui.style)
	{
		button.normal = g_ui.loadSprite("data/ui/sprites/rect-interact-normal.png");
		button.pressed = g_ui.loadSprite("data/ui/sprites/rect-interact-clicked.png");
		button.focused = g_ui.loadSprite("data/ui/sprites/rect-interact-focus.png");
		button.mesh = new PatchRectStyle(button.normal, Pad(6));
		button.pad = Pad(0, 10, 12, 12);
		
		panel.sprite = g_ui.addSinglePixel(color(196, 247, 255));
		panel.mesh = new SpriteQuadStyle(panel.sprite);

		scrollbar.width = 20;
		scrollbar.trough.sprite = g_ui.addSinglePixel(color(0, 148, 255, 128));
		scrollbar.trough.mesh = new SpriteQuadStyle(scrollbar.trough.sprite);
		scrollbar.upArrow = g_ui.loadSprite("data/ui/sprites/arrow-up.png");
		scrollbar.downArrow = g_ui.loadSprite("data/ui/sprites/arrow-down.png");

		defaultFont = g_ui.loadFont("data/ui/fonts/averia/Averia-Regular.ttf", 20);
		defaultFontColor = vec3(0.2, 0.5, 1);
	}

	Message.font = g_ui.loadFont("data/ui/fonts/averia/Averia-Bold.ttf", 20);

	/// BEGIN - Dialog initialization
	DialogState ds;

	bool showDialog = true;
	ds.buttons.reserve(8);

	void dialogCallback(Dialog p_dialog)
	{
		assert(p_dialog.responses.length <= ds.buttons.length);
		ds.current = p_dialog;

		ds.messageBox.addChild(new Message("Kitty:", p_dialog.message, kittyColor));

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

	Widget dialogbox = new VBox(tmp_widgets, 0, true).withBounds(Bounds(0, 400), Bounds.none);

	Widget[] messages;
	string kitty = "Kitty:";
	string boto = "Boto:";
	foreach(line; File("data/dialog.tsv", "r").byLine())
	{
		if(line.length == 0 || line[0] == '#')
		{
			continue;
		}
		string[] fields = cast(string[]) line.split("\t");
		assert(fields.length == 2);
		if(fields[0] == "K")
		{
			messages ~= new Message(kitty, fields[1].dup, kittyColor);
		}
		else
		{
			messages ~= new Message(boto, fields[1].dup, botoColor);
		}
	}

	ds.messageBox = new VBox(messages, 10, true);

	Dialog currentDialog = testDialog();
	Widget dialogWidget = new Padding(
		dialogbox, 
		Pad(8), 
		g_ui.style.panel.mesh.create(g_ui));
	/// END - Dialog initialization

	SpriteId upclickSprite = g_ui.loadSprite("data/test/ui_sprites/upclick.png");

	TextBox frameTime = new TextBox(g_ui.style.defaultFont, "Getting data...", 64, vec3(0.5));
	TextBox o2Text = new TextBox(g_ui.style.defaultFont, "Getting data...", 32, vec3(1));

	Modal uiModal = new Modal([
		// Pause menu
		new HodgePodge([
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
			new Anchor(o2Text, vec2(0.99), vec2(1)),
 		]),

		new HodgePodge([
			new Anchor(
				new HBox([
					new TextBox(g_ui.style.defaultFont, "Frame Time\nMax\nAverage", vec3(0.5)), 
					frameTime
				], 5),
				vec2(0.99, 0.99),
				vec2(1, 1))
		]),
	]);

	g_ui.setRootWidget(uiModal);

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

		frameTime.setText(g_frameTime);
		o2Text.setText(g_oxygenText);

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
	ownerTid.send(UIReady());
}
