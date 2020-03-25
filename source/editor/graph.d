// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module editor.graph;

import std.format;

import gl3n.linalg : vec3;

import lanlib.types;
import game.dialog;
import ui;

version(lantana_editor)
final class DialogNode : Padding, Interactible
{
	Dialog dialog;

	TextBox tag;

	TextBox messageLabel;
	TextBox dateLabel;
	TextBox timeLabel;

	TextInput message;
	TextInput date;
	TextInput time;

	VBox box;
	Button responseButton;

	ivec2 lineStart, lineEnd;

	RealSize size;

	DialogNode[] responses;
	/// Lines to responses
	Line[] lines;

	// For dragging the window around
	InteractibleId bar;

	this(UIRenderer p_ui, Dialog p_dialog = new Dialog("Put your text here!", 0, []))
	{
		box = new VBox([], 6);
		box.withBounds(Bounds(0, 300), Bounds.none);

		super(new HBox([box], 12, Alignment.CENTER), Pad(6), new ImageBox(p_ui, color(120, 120, 255, 80), RealSize(1)));
		dialog = p_dialog;
		position = dialog.edit_position;
	}

	public override void initialize(UIRenderer p_renderer, UIView p_view)
	{
		super.initialize(p_renderer, p_view);

		HBox hb = cast(HBox)getChild();
		responseButton = new Button(p_renderer, new Spacer(RealSize(0, 100)), (Widget) {});
		hb.addChild(responseButton);

		tag = new TextBox(dialog.getTag());

		messageLabel = new TextBox("Message:");
		dateLabel = new TextBox("Date:");
		timeLabel = new TextBox("Pause Time:");

		message = new TextInput(1024, dialog.message);
		date = new TextInput(64, dialog.date);
		time = new TextInput(32, format("%f", dialog.pauseTime));

		box.addChild(tag);
		box.addChild(new HBox([timeLabel.withBounds(Bounds(120), Bounds.none), time]));
		box.addChild(new HBox([dateLabel.withBounds(Bounds(120), Bounds.none), date]));
		box.addChild(messageLabel.withBounds(Bounds(120), Bounds.none));
		box.addChild(message);

		bar = view.addInteractible(this);

		foreach(line; lines)
		{
			line.initialize(view.renderer, view);
			line.prepareRender(ivec2(0));
		}
	}

	public override RealSize layout(SizeRequest p_request)
	{
		size = super.layout(p_request);
		view.setInteractSize(bar, size);
		return size;
	}

	public override void prepareRender(ivec2 p_pen)
	{
		dialog.edit_position = p_pen;
		super.prepareRender(p_pen);
		view.setInteractPosition(bar, p_pen);
		
		lineStart = ivec2(size.width, size.height/2) + p_pen;
		lineEnd = ivec2(0, size.height - 20) + p_pen;

		foreach(line; lines)
		{
			line.prepareRender(ivec2(0));
		}
	}

	public void addResponse(DialogNode node)
	{
		auto line = new Line(AlphaColor(255), 
			Thunk!ivec2(()
			{
				return lineStart;
			}), 
			Thunk!ivec2(()
			{
				return node.lineEnd;
			})
		);
		if(view)
		{
			line.initialize(view.renderer, view);
			line.prepareRender(ivec2(0));
		}
		lines ~= line;
	}

	public override void focus(){}
	public override void unfocus() 
	{
		tag.setColor(view.renderer.style.defaultFontColor);
	}
	public override void interact()
	{
		tag.setColor(vec3(1));
	}

	public override void drag(ivec2 p_dragAmount)
	{
		position += p_dragAmount;
		view.requestUpdate();
	}

	public override short priority()
	{
		return 2;
	}

	public Dialog getDialog()
	{
		return dialog;
	}
}