// Part of NP-ToDo
// copyright Devin Lee Hastings a.k.a. needleful

module app.main;

import core.memory;
import std.format;
import std.math;
import std.stdio;

import bindbc.sdl;

import lantana.input;
import lantana.math;
import lantana.render;
import lantana.types;
import lantana.ui;

import app.todo;

private enum forcedMain = true;

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
	import std.string : toStringz;

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
		writeln("Starting Lantana in main...");
		return runGame();
	}
}

int runGame()
{
	Project project = loadProject("np-todo.todo");
	storeProject(project, "np-todo.todo");

	Window window = Window(1280, 720, "NP ToDo");
	RealSize ws = window.getSize();
	auto ui = new UIRenderer(ws, window.getDPI());
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
		defaultFontColor = Vec3(1, 1, 1);

		debug
		{
			textInput.cursor = ui.addSinglePixel(color(12, 12, 12, 255));
			textInput.focused = Vec3(1, 0.5, 0.9);
			textInput.normal = Vec3(0.9, 0.5, 0.4);
		}
	}
	glcheck();
	ui.setRootWidget(new HodgePodge([
		new TextBox("Hello!")
	]));
	ui.initialize();
	glcheck();

	Input input = Input();

	float delta = 0.001f;

	debug
	{
		File frame_log = File("logs/framerate.tsv", "w");
		frame_log.writeln("Frametime\tMax\tAverage");
	}

	enum uiFrameRate = 1/45.0;
	float uiFrameTime = 0;
	int runningFrame = 1;
	float time_accum = 0;
	float time = 0;
	window.grabMouse(false);

	while(!window.state[WindowState.CLOSED])
	{
		glcheck();
		float delta_ms = window.delta_ms();
		delta = delta_ms/1000.0;
		uiFrameTime += delta;
		time += delta;
	
		window.pollEvents(&input);

		if(window.state[WindowState.RESIZED])
		{
			ws = window.getSize();
			ui.setSize(ws);
		}
		
		glcheck();
		window.beginFrame();
		
		ui.updateInteraction(delta, &input);
		ui.updateLayout();
		ui.render();
		window.endFrame();
		glcheck();
	}
	debug writeln("Game closing");
	return 0;
}