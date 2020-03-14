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

enum cam_speed = 8;

float g_timescale = 1;

enum g_MemoryCapacity = 1024*1024*64;

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
//__gshared string g_frameTime;

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

	//TextBox frameTime = new TextBox(g_ui.style.defaultFont, "", 64);

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
	 		//new Anchor(
				//new HBox([
				//	new TextBox(g_ui.style.defaultFont, "Frame Time\nMax\nAverage"), 
				//	frameTime
				//], 5),
				//vec2(0.99, 0.99),
				//vec2(1, 1))
 		]));

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

		//frameTime.setText(g_frameTime);
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
	audio.startMusic("data/audio/music/floating-full.ogg", 0);

	auto mainMem = BaseRegion(g_MemoryCapacity);

	auto sysMesh = AnimMesh.System(loadMaterial("data/shaders/animated3d.vert", "data/shaders/material3d.frag"));
	sysMesh.meshes = mainMem.makeOwnedList!(AnimMesh.Mesh)(1);

	AnimMesh.Uniforms.global globals;
	globals.light_direction = vec3(-0.1,-0.3,0.9);
	globals.light_bias = 0.6;
	globals.area_ceiling = -1;
	globals.area_span = 3;
	globals.gamma = 1;

	auto mesh = sysMesh.loadMesh("data/meshes/kitty-astronaut.glb", mainMem);
	auto instances = mainMem.makeList!(AnimMesh.Instance)(1);
	instances[0] = AnimMesh.Instance(mesh, Transform(1, vec3(0.53, 0, 0), vec3(0, -40, 180)), mainMem);
	instances[0].play("Idle", true);


	auto skyBox = SkyMesh.System(loadMaterial("data/shaders/skybox.vert", "data/shaders/skybox.frag"));
	skyBox.meshes = mainMem.makeOwnedList!(SkyMesh.Mesh)(1);
	auto sky = skyBox.loadMesh("data/meshes/skybox.glb", mainMem);
	SkyMesh.Instance[] skyMeshes = mainMem.makeList!(SkyMesh.Instance)(1);
	skyMeshes[0].transform = Transform(1);
	skyMeshes[0].mesh = sky;

	SkyMesh.Uniforms.global skyUni;
	skyUni.gamma = 1.8;

	auto camera = Camera(vec3(0, -1.2, -5), cast(float)ws.width/ws.height, 60);
	auto lights = LightPalette("data/palettes/skyTest.png", mainMem);

	float runningMaxDelta_ms = -1;
	float accumDelta_ms = 0;
	bool paused = false;

	Input input = Input();
	uint frame = 0;

	//string debugFormat = ": %6.3f\n: %6.3f\n: %6.3f";

	receiveOnly!UIReady();
	g_ui.initialize();

	float delta = 0.001f;
	uiThread.send(UIEvents(delta, input, window.state, window.getSize()));

	vec2 velCamRot = vec2(0);
	float accelCamRot = 2;
	float dampCamRot = 0.99;

	debug
	{
		File frame_log = File("logs/framerate.tsv", "w");
		frame_log.writeln("Frametime\tMax\tAverage");
	}
	int runningFrame = 1;
	while(!window.state[WindowState.CLOSED])
	{
		float delta_ms = window.delta_ms();
		delta = g_timescale*delta_ms/1000.0;
		runningMaxDelta_ms = delta_ms > runningMaxDelta_ms ? delta_ms : runningMaxDelta_ms;
		accumDelta_ms += delta_ms;

		if(frame % 256 == 0)
		{
			//g_frameTime = format(debugFormat, delta_ms, runningMaxDelta_ms, accumDelta_ms/256);

			runningMaxDelta_ms = delta_ms;
			accumDelta_ms = delta_ms;
			runningFrame = 1;
		}
	
		window.pollEvents(&input);

		if(window.state[WindowState.RESIZED])
		{
			ws = window.getSize();
			camera.set_projection(
				Projection(cast(float)ws.width/ws.height, 60, DEFAULT_NEAR_PLANE, DEFAULT_FAR_PLANE)
			);
		}

		if(input.is_just_pressed(Input.Action.PAUSE))
		{
			paused = !paused;
			window.grab_mouse(!paused);
		}

		if(!paused)
		{
			velCamRot += input.mouse_movement*delta*accelCamRot;
		}
		velCamRot *= dampCamRot;
		camera.rot += velCamRot;

		instances[0].transform.rotate_degrees(-0.1*delta, 1.2*delta, 0.71*delta);
		sysMesh.update(delta, instances);

		UIReady _ = receiveOnly!UIReady();
		window.begin_frame();

		vec3 pos = camera.pos;
		camera.pos = vec3(0);

		skyUni.projection = camera.vp();
		skyBox.render(skyUni, lights.palette, skyMeshes);

		camera.pos = pos;
		globals.projection = camera.vp();

		sysMesh.render(globals, lights.palette, instances);
		g_ui.render();

		uiThread.send(UIEvents(delta, input, window.state, window.getSize()));
		window.end_frame();

		debug frame_log.writefln("%f\t%f\t%f", delta_ms, runningMaxDelta_ms, accumDelta_ms/runningFrame);
		frame ++;
		runningFrame ++;
	}
	debug writeln("Game closing");
	return 0;
}