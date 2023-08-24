// Part of NP-ToDo
// copyright Devin Lee Hastings a.k.a. needleful

module app.ui;

import std.algorithm.iteration: map;
import std.array: array;
import std.stdio;

import lantana.input;
import lantana.math;
import lantana.render;
import lantana.types;
import lantana.ui;

import app.todo;

UIRenderer makeRenderer(ref Window window) {
	auto ui = new UIRenderer(window.getSize(), window.getDPI());
	with(ui.style)
	{
		button.normal = ui.loadSprite("data/ui/sprites/rect-interact-normal.png");
		button.pressed = ui.loadSprite("data/ui/sprites/rect-interact-clicked.png");
		button.focused = ui.loadSprite("data/ui/sprites/rect-interact-focus.png");
		button.mesh = new PatchRectStyle(button.normal, Pad(6));
		button.pad = Pad(4, 6);
		
		panel.sprite = ui.addSinglePixel(color(196, 247, 255));
		panel.mesh = new SpriteQuadStyle(panel.sprite);

		scrollbar.width = cast(ubyte)(ui.getDPI().x/5.75);
		scrollbar.trough.sprite = ui.addSinglePixel(color(0, 148, 255, 128));
		scrollbar.trough.mesh = new SpriteQuadStyle(scrollbar.trough.sprite);
		scrollbar.upArrow = ui.loadSprite("data/ui/sprites/arrow-up.png");
		scrollbar.downArrow = ui.loadSprite("data/ui/sprites/arrow-down.png");

		defaultFont = ui.loadFont("data/ui/fonts/ClearSans.ttf", 13);
		defaultFontColor = Vec3(.7, .7, .7);

		textInput.cursor = ui.addSinglePixel(color(255, 255, 255, 255));
		textInput.focused = Vec3(1, 1, 1);
		textInput.normal = Vec3(.7, .7, .7);
	}
	ui.initialize();
	return ui;
}

class ProjectEditor : Scrolled {
	VBox taskList;

	this(Project project) {
		VBox mainWindow = new VBox([
			new TextInput(256, project.info["project"]),
			taskList = new VBox(array(project.tasks.map!edit)),
			new Button("New Task", (Widget source) {createTask();})
		]);
		super(new Padding(
			mainWindow, 
			Pad(10, 15), 
			new ImageBox(color(0,0,0,255), RealSize(128, 128)))
		);
	}

	void createTask() {
		taskList.addChild(edit(defaultTask()));
	}
}

class TaskEditor : VBox {
	VBox info;
	VBox subTasks;
	TextInput summary;
	TextInput notes;
	MultiContainer tags;

	this(Task task) {
		Widget tagbox(string text) {
			return new TextBox(text);
		}

		super([
			summary = new TextInput(256, task.summary),
			new Padding(
				info = new VBox([
					notes = new TextInput(1024, task.notes),
					tags = new HBox(
						[cast(Widget) new TextInput(64, "tag name")]
						~ array(task.tags.map!tagbox), 8),
					subTasks = new VBox(array(task.subTasks.map!edit)),
					new Button("New sub-task", (Widget source) {addSubTask();})
				]),
				Pad(0, 0, 10, 0))
		]);
	}

	void addSubTask() {
		subTasks.addChild(edit(defaultTask()));
	}
}

private Task defaultTask() {
	Task t;
	t.summary = "New Task";
	t.notes = "Track details about your task";
	return t;
}

private Widget edit(Task task) {
	return new TaskEditor(task);
}