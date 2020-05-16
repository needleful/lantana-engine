// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.main;
version(lantana_game):

import std.format;
import std.stdio;

import gl3n.linalg;

import game.bipple;
import game.prolog_engine;
import game.scene;
import game.systems;

import lantana.input;
import lantana.math;
import lantana.render;
import lantana.types;
import lantana.ui;

// Force the game to run on main() instead of WinMain()
enum forcedMain = true;

enum MAIN_MEM_LIMIT = 1024*1024*18;

int runGame()
{
	Window window = Window(1280, 720, "Bipples");
	window.grabMouse(false);

	PrologInterface pl = PrologInterface("Bipples", "data/prolog/brain.save", "data/prolog/brain.pl");
	scope(exit) pl.save();
	Bipple.engine = new BippleEngine();

	UIRenderer ui = new UIRenderer(window.getSize(), window.getDPI());
	with(ui.style)
	{
		button.normal = ui.loadSprite("data/ui/sprites/rect-interact-normal.png");
		button.pressed = ui.loadSprite("data/ui/sprites/rect-interact-clicked.png");
		button.focused = ui.loadSprite("data/ui/sprites/rect-interact-focus.png");
		button.mesh = new PatchRectStyle(button.normal, Pad(6));
		button.pad = Pad(8, 8, 12, 12);
		
		panel.sprite = ui.addSinglePixel(color(196, 247, 255));
		panel.mesh = new SpriteQuadStyle(panel.sprite);

		scrollbar.width = cast(ubyte)(ui.getDPI().x/5.75);
		scrollbar.trough.sprite = ui.addSinglePixel(color(0, 148, 255, 128));
		scrollbar.trough.mesh = new SpriteQuadStyle(scrollbar.trough.sprite);
		scrollbar.upArrow = ui.loadSprite("data/ui/sprites/arrow-up.png");
		scrollbar.downArrow = ui.loadSprite("data/ui/sprites/arrow-down.png");

		defaultFont = ui.loadFont("data/ui/fonts/ClearSans.ttf", 13);
		defaultFontColor = vec3(0.8, 0.8, 0.8);
	}

	string statusFormat = "\n%3.02f\n%3.02f";
	TextBox bippleStatus = new TextBox("", 16);
	ui.setRootWidget(
		new Anchor(
			new HBox([
					new TextBox("Status\nFood:\nEnergy:"),
					bippleStatus
				],
				8
			),
			vec2(.95, .95),
			vec2(1, 1)
		)
	);
	ui.initialize();

	Input input = Input();
	auto mainMem = BaseRegion(MAIN_MEM_LIMIT);
	auto scene = new SceneManager(mainMem);
	scene.load("data/scenes/test.sdl");

	bool orbit = false;
	enum uiUpdateTime = 1;
	float uiUpdateTimer = uiUpdateTime;
	while(!window.state[WindowState.CLOSED])
	{
		window.pollEvents(&input);
		float delta = window.delta_ms()/1000;
		uiUpdateTimer += delta;

		if(window.state[WindowState.RESIZED])
		{
			RealSize ws = window.getSize();
			ui.setSize(ws);
			scene.camera.setProjection(ws.width/cast(float)ws.height, camFOV);
		}

	 	// Camera controls
		bool newOrbit = input.isClicked(Input.Mouse.Right) || input.isClicked(Input.Mouse.Middle);
		if(orbit != newOrbit)
		{
			orbit = newOrbit;
			window.grabMouse(orbit);
		}
		if(orbit)
		{
			vec2 camRot = input.mouseMove*camSpeed*delta;
			camRot.y *= -1;
			if(scene.camera.angle.y + camRot.y > 90 || scene.camera.angle.y + camRot.y < 5)
			{
				camRot.y = 0;
			}
			scene.camera.rotateDegrees(camRot);
		}
		import std.math: pow;
		float zoom = pow(1.2, input.mouseWheel.y);
		if(scene.camera.distance*zoom < 0.001 || scene.camera.distance*zoom > 40)
		{
			zoom = 1;
		}
		scene.camera.distance *= zoom;
		// end camera controls

		scene.update(delta);

		if(uiUpdateTimer >= uiUpdateTime)
		{
			with(scene.ecs.get!Bipples[0])
			{
				bippleStatus.setText(format(statusFormat, needs[0].value, needs[1].value));
			}
			uiUpdateTimer = 0;
		}

		ui.updateInteraction(delta, &input);
		ui.updateLayout();

		window.beginFrame();
		scene.render();
		ui.render();
		window.endFrame();
	}

	debug writeln("Game closing");
	return 0;
}



static if(forcedMain)
{
	int main()
	{
		writeln("Starting Lantana in main...");
		return runGame();
	}
}
else version(Windows)
{
	import core.runtime;
	import core.sys.windows.windows;

	extern(Windows)
	int WinMain(HINSTANCE p_instance, HINSTANCE p_prev, LPSTR p_command, int p_show)
	{
		int result;
		try
		{
			Runtime.initialize();
			result = runGame();
			Runtime.terminate();
		}
		catch(Throwable e)
		{
			auto msg = format("There was an error:\r\n%s"w, e);
			msg ~= '\0';
			MessageBoxW(null, msg.ptr, null, MB_ICONEXCLAMATION);
			result = 0;
		}
		return result;
	}
}
else
{
	int main()
	{
		return runGame();
	}
}