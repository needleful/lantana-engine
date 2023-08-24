// Part of NP-ToDo
// copyright Devin Lee Hastings a.k.a. needleful

module app.main;

import core.memory;
import core.thread.osthread: Thread;
import core.time;

import std.format;
import std.math;
import std.stdio;

import lantana.input;
import lantana.math;
import lantana.render;
import lantana.types;
import lantana.ui;

import app.todo;
import app.ui;

version(Windows) {
	import app.platform.windows;
}
else
{
	int main()
	{
		writeln("Starting NP-ToDo in main...");
		return run();
	}
}

struct action {
	string name;
	key shortcut;
	void delegate() callback;
}

int run()
{
	Window window = Window(1280, 720, "NP ToDo");
	UIRenderer ui;

	void newFile() {
		auto editor = new ProjectEditor(Project.empty());
		ui.setRootWidget(editor);
	}

	void open() {
		auto editor = new ProjectEditor(loadProject("np-todo.todo"));
		ui.setRootWidget(editor);
	}

	void save() {
	}

	void saveAs() {
	}

	void exit() {
		window.requestClose();
	}

	action[] fileActions = [
		{"&New Project", key('n').ctrl(), &newFile},
		{"&Open Project...", key('o').ctrl(), &open},
		{"&Save", key('s').ctrl(), &save},
		{"Save &As...", key('s').shift().ctrl(), &saveAs},
		{"E&xit", key('w').shift().ctrl(), &exit}
	];

	foreach(ref action a; fileActions) {
		window.shortcuts[a.shortcut.toInt()] = a.callback;
	}

	ui = makeRenderer(window);
	window.createMenu(fileActions);
	newFile();

	Input input = Input();
	float delta = 0.001f;

	window.grabMouse(false);

	while(!window.state[WindowState.CLOSED])
	{
		delta = window.delta_ms()/1000.0;
	
		window.pollEvents(&input);

		if(window.state[WindowState.RESIZED])
		{
			ui.setSize(window.getSize());
		}

		ui.updateInteraction(delta, &input);
		ui.updateLayout();

		if(ui.needsRedraw) {
			ui.render();
			window.endFrame();
		}
		else {
			Thread.sleep(dur!"msecs"(16));
		}
	}
	return 0;
}