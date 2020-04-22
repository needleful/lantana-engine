// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.ui;

version(lantana_game):

import core.memory;
import std.concurrency;
import std.format;
import std.math;
import std.stdio;
import std.string: split;

import bindbc.sdl;

import game.dialog;
import game.main;
import game.skybox;

import lantana.audio;
import lantana.file.gltf2;
import lantana.math;
import lantana.types;
import lantana.file.lgbt;

import lantana.input;
import lantana.render;
import lantana.ui;

import gl3n.linalg;

private static immutable(vec3) kittyColor = vec3(0.8, 0.27, 0.83);
private static immutable(vec3) bardanColor = vec3(0.2, 0.75, 0.3);

enum dialogFile = "data/wip_dialog.sdl";
enum wip_backup = "data/wip_dialog.backup.sdl";

final class DialogButton : Button
{
	Dialog dialog;
	
	public this(UIRenderer p_renderer, Dialog.Callback p_callback)
	{
		visible = false;

		super(p_renderer, new TextBox("", 128), 
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
			new TextBox(content)
		];
		super.initialize(p_renderer, p_view);
	}
}

debug class InteractiveEditor : SingularContainer
{
	TextInput requirements, effects, time, message;

	public Interactible.Callback onCancel;
	public void delegate(Dialog) onComplete;

	override void initialize(UIRenderer p_renderer, UIView p_view)
	{
		requirements = new TextInput(256);
		effects = new TextInput(256);
		time = new TextInput(16);
		message = new TextInput(512);

		child = new Padding(
			new VBox([
				new TextBox("Requirements"),
				requirements,
				new TextBox("Effects"),
				effects,
				new TextBox("Pause Time"),
				time,
				new TextBox("Message"),
				message,
				new HBox([
					new Button(g_ui, "Cancel", onCancel),
					new Button(g_ui, "Create", &createDialog)
				], 20)
			], 10),
			Pad(10),
			g_ui.style.panel.mesh.create(p_renderer));

		super.initialize(p_renderer, p_view);
	}

	public override RealSize layout(SizeRequest p_request)
	{
		if(!visible)
		{
			return layoutEmpty();
		}
		return child.layout(p_request);
	}

	void createDialog(Widget _)
	{
		import std.conv;
		Dialog d = new Dialog(
			message.text.idup(),
			time.text.to!float(),
			[]
		);
		d.setRequirements(requirements.text.idup()),
		d.setRequirements(effects.text.idup());

		if(onComplete)
		{
			onComplete(d);
		}
	}
}

struct DialogState
{
	Dialog current;
	DialogButton[] buttons;
	VBox messageBox;
	float timer;
	float[string] flags;
}

struct UIReady{}
struct UICancel
{
	immutable(Throwable) thrown;
	this(Throwable t)
	{
		thrown = cast(immutable(Throwable))t;
	}
}

struct UIEvents
{
	float delta;
	Bitfield!WindowState window;
	RealSize size;

	this(float p_delta, Bitfield!WindowState p_window, RealSize p_size)
	{
		delta = p_delta;
		window = p_window;
		size = p_size;
	}
}

__gshared UIRenderer g_ui;
__gshared string g_frameTime;
__gshared string g_oxygenText;
__gshared Input* g_uiInput;

void uiMain()
{
	scope(failure) ownerTid.send(UICancel(new Exception("Unknown error")));
	try
	{
		uiRun();
		ownerTid.send(UIReady());
	}
	catch(Throwable e)
	{
		ownerTid.send(UICancel(e));
	}
}

void uiRun()
{
	with(g_ui.style)
	{
		button.normal = g_ui.loadSprite("data/ui/sprites/rect-interact-normal.png");
		button.pressed = g_ui.loadSprite("data/ui/sprites/rect-interact-clicked.png");
		button.focused = g_ui.loadSprite("data/ui/sprites/rect-interact-focus.png");
		button.mesh = new PatchRectStyle(button.normal, Pad(6));
		button.pad = Pad(8, 8, 12, 12);
		
		panel.sprite = g_ui.addSinglePixel(color(196, 247, 255));
		panel.mesh = new SpriteQuadStyle(panel.sprite);

		scrollbar.width = cast(ubyte)(g_ui.getDPI().x/5.75);
		scrollbar.trough.sprite = g_ui.addSinglePixel(color(0, 148, 255, 128));
		scrollbar.trough.mesh = new SpriteQuadStyle(scrollbar.trough.sprite);
		scrollbar.upArrow = g_ui.loadSprite("data/ui/sprites/arrow-up.png");
		scrollbar.downArrow = g_ui.loadSprite("data/ui/sprites/arrow-down.png");

		defaultFont = g_ui.loadFont("data/ui/fonts/ClearSans.ttf", 13);
		defaultFontColor = vec3(0.0, 0.583, 1);

		debug
		{
			textInput.cursor = g_ui.addSinglePixel(color(12, 12, 12, 255));
			textInput.focused = vec3(1, 0.5, 0.9);
			textInput.normal = vec3(0.9, 0.5, 0.4);
		}
	}

	Message.font = g_ui.loadFont("data/ui/fonts/ClearSans-Bold.ttf", 13);

	FontId sysFont = g_ui.loadFont("data/ui/fonts/ClearSans.ttf", 10);

	/// BEGIN - Dialog initialization
	DialogState ds;

	bool showDialog = true;
	ds.buttons.reserve(8);

	int responseCount = 0;
	string firstDate = "3:05 AM";
	string secondDate = "2:41 PM";

	void dialogCallback(Dialog p_dialog)
	{
		ds.flags["_oxygen"] = g_oxygen;
		foreach(effect; p_dialog.effects)
		{
			if(effect.key !in ds.flags)
			{
				ds.flags[effect.key] = 0;
			}
			switch(effect.op)
			{
				case Effect.Op.Set:
					ds.flags[effect.key] = effect.value;
					break;
				case Effect.Op.Add:
					ds.flags[effect.key] += effect.value;
					break;
				case Effect.Op.Subtract:
					ds.flags[effect.key] -= effect.value;
					break;
				case Effect.Op.Multiply:
					ds.flags[effect.key] *= effect.value;
					break;
				case Effect.Op.Divide:
					ds.flags[effect.key] /= effect.value;
					break;
				default:
					writefln("WARNING: Unknown op '%s' in effect '%s'", effect.op, effect);
					break;
			}
		}

		ds.current = p_dialog;

		if(responseCount <= 1)
		{
			if(responseCount == 0)
				ds.messageBox.addChild(new Padding(new TextBox(sysFont, "sent "~firstDate), Pad(10, -10, 0, 0)));
			else
				ds.messageBox.addChild(new Padding(new TextBox(sysFont, "sent "~secondDate), Pad(10, -10, 0, 0)));
		}
		responseCount ++;

		ds.messageBox.addChild(new Message("Kitty:", p_dialog.message, kittyColor));

		bool reqsMet(Dialog p_response)
		{
			if(p_response.requirements.length == 0)
			{
				return true;
			}
			bool reqMet = true;
			Requirement.Next rcont = Requirement.Next.None;
			foreach(req; p_response.requirements)
			{
				if(req.key !in ds.flags)
				{
					ds.flags[req.key] = 0;
				}

				float test = ds.flags[req.key];
				switch(rcont)
				{
					case Requirement.Next.None:
						reqMet = req(test);
						break;
					case Requirement.Next.Or:
						reqMet = reqMet || req(test);
						break;
					case Requirement.Next.And:
						reqMet = reqMet && req(test);
						break;
					default:
						writefln("WARNING: unknown continuation '%s' in requirement '%s'", rcont, req);
						break;
				}
				rcont = req.next;
			}
			return reqMet;
		}

		int setButtons = 0;
		foreach(resp; p_dialog.responses)
		{
			if(reqsMet(resp))
			{
				ds.buttons[setButtons].setVisible(true);
				ds.buttons[setButtons].setDialog(resp);
				setButtons ++;
			}
		}

		for(ulong i = setButtons; i < ds.buttons.length; i++)
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
	tmp_widgets.reserve(ds.buttons.length + 2);

	tmp_widgets ~= new TextBox("Compose Your Message!");
	tmp_widgets ~= new Spacer(RealSize(12));
	foreach(button; ds.buttons)
	{
		tmp_widgets ~= button;
	}

	debug
	{
		InteractiveEditor iedit = new InteractiveEditor();

		iedit.onCancel = (_)
		{
			iedit.setVisible(false);
		};

		tmp_widgets ~= new Button(g_ui, new TextBox("[+ Add Response +]"), (_) {
			writeln("Wumbo");
			iedit.setVisible(true);
		});
	}

	HFlags expand = HFlags(HFlag.Expand);

	Widget dialogbox = 
		new VBox(tmp_widgets, 0, HFlags(HFlag.Expand, HFlag.Center))
			.withBounds(Bounds(0, 4*g_ui.getDPI().x), Bounds.none);

	Widget[] messages;
	string kitty = "Kitty:";
	string bardan = "Bardan:";
	foreach(line; File("data/dialog.tsv", "r").byLine())
	{
		if(line.length == 0 || line[0] == '#')
		{
			continue;
		}
		string[] fields = cast(string[]) line.split("\t");
		assert(fields.length == 2);

		if(fields[0] == "K")
			messages ~= new Message(kitty, fields[1].dup, kittyColor);
		else if(fields[0] == "%")
			messages ~= new Padding(new TextBox(sysFont, fields[1].dup), Pad(10, -10, 0, 0));
		else
			messages ~= new Message(bardan, fields[1].dup, bardanColor);
	}

	ds.messageBox = new VBox(messages, 10, HFlags(HFlag.Expand));

	string start;
	auto map = loadDialog(dialogFile, start);
	Dialog currentDialog = map[start];
	
	Widget dialogWidget = new Padding(
		dialogbox, 
		Pad(8), 
		g_ui.style.panel.mesh.create(g_ui));

	debug iedit.onComplete = (Dialog d)
	{
		d.edit_position = 
			ds.current.edit_position 
			+ ivec2(20, cast(int)ds.current.responses.length * 5);

		ds.current.responses ~= d;
		ds.buttons[ds.current.responses.length - 1].setDialog(d);
		ds.buttons[ds.current.responses.length - 1].setVisible(true);
		iedit.setVisible(false);

		import std.file;
		if(dialogFile.exists())
		{
			copy(dialogFile, wip_backup);
		}

		storeDialog(dialogFile, map[start]);
	};
	/// END - Dialog initialization

	debug TextBox frameTime = new TextBox(sysFont, "Getting data...", 64, vec3(0.5));
	TextBox o2Text = new TextBox(sysFont, "Getting data...", 32, vec3(1));

	Widget hints = new Anchor(
		new VBox([
			new TextBox("When you run out of oxygen, you will die.", vec3(1)),
			new TextBox("Use the mouse to look around", vec3(1)),
			new TextBox("Press [TAB] to toggle your messenger", vec3(1))
		], 6),
		vec2(0.1, 0.5),
		vec2(0, 0.5)
	);

	Modal uiModal = new Modal([
		// Pause menu
		new AnchoredBox([
			g_ui.style.panel.mesh.create(g_ui),
			new Padding(
				new VBox([
					new ImageBox(g_ui, "data/ui/sprites/lantana-logo.png"),
					new TextBox(sysFont, "Gamma-Wave Messenger (Version 639.11.3)"),
					new AnchoredBox([new Scrolled(new Padding(ds.messageBox, Pad(12)), 0)], 
						vec2(0, 0),
						vec2(1, 0.85)),
					], 12, HFlags(HFlag.Center)),
				Pad(8)),
			new Positioned(
				dialogWidget,
				vec2(1, 0),
				vec2(0, 0))
			],

			vec2(0.02,0.02),
			vec2(0.28, .98),
		).withBounds(Bounds(3.5*g_ui.getDPI().x, 6*g_ui.getDPI().x), Bounds.none),
		hints
	]);

	debug TextBox[string] debugMap;
	debug VBox debugBox = new VBox([
			new HBox([
				new TextBox(sysFont, "Frame Time\nMax\nAverage", vec3(0.5)), 
				frameTime,
			], 5),
		], 6);

	debug
	{
		g_ui.setRootWidget(
		new HodgePodge([
			uiModal,
			new Anchor(iedit, vec2(0.5), vec2(0.5)),
			new Anchor(o2Text, vec2(0.5, 0.99), vec2(0.5, 1)),
			new Anchor(debugBox, vec2(.98, 0.02), vec2(1, 0))
		]));
		iedit.setVisible(false);
	}
	else
	{
		g_ui.setRootWidget(
		new HodgePodge([
			uiModal, 
			new Anchor(o2Text, vec2(0.5, 0.99), vec2(0.5, 1))
		]));
	}

	// Needs to be run after initialization
	dialogCallback(currentDialog);

	uiModal.setMode(1);

	ownerTid.send(UIReady());
	bool paused = false;
	void processEvents(UIEvents events)
	{
		// Cinematic mode
		//o2Text.setVisible(false);

		if(events.window[WindowState.RESIZED])
		{
			g_ui.setSize(events.size);
		}

		if(g_uiInput.keyboard.isJustPressed(SDL_SCANCODE_TAB))
		{
			paused = !paused;
			if(paused)
			{
				uiModal.setMode(0);
				if(hints.isVisible())
				{
					hints.setVisible(false);
				}
			}
			else
			{
				uiModal.setMode(1);
			}
		}

		if((ds.timer += events.delta) >= ds.current.pauseTime)
		{
			showDialog = true;
			debug foreach(string key, float value; ds.flags)
			{
				if(key !in debugMap)
				{
					TextBox t = new TextBox(sysFont, format("%s", value), 12, vec3(0.5));
					debugMap[key] = t;
					debugBox.addChild(new HBox([
							new TextBox(sysFont, key, vec3(0.5)).withBounds(Bounds(100, double.infinity), Bounds.none),
							t
						])
					);
				}
				else
				{
					debugMap[key].setText(format("%s", value));
				}
			}
		}

		g_ui.updateInteraction(events.delta, g_uiInput);

		dialogWidget.setVisible(showDialog);

		debug frameTime.setText(g_frameTime);
		o2Text.setText(g_oxygenText);

		g_ui.updateLayout();
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
