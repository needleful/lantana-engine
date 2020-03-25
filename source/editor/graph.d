// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module editor.graph;

import std.format;

import lanlib.types;
import game.dialog;
import ui;

final class DialogWindow : Widget
{
	
}

final class DialogNode : Padding
{
	Dialog dialog;

	TextBox tag;

	TextBox messageLabel;
	TextBox dateLabel;
	TextBox timeLabel;

	TextInput message;
	TextInput date;
	TextInput time;

	DialogNode[] responses;

	// For dragging the window around
	InteractibleId bar;

	this(ivec2 p_position, Dialog p_dialog = new Dialog("Put your text here!", 0, []))
	{
		super(new VBox([], 6, HFlags(HFlag.Expand)), Pad(6));
		position = p_position;
		dialog = p_dialog;
	}

	public override void initialize(UIRenderer p_renderer, UIView p_view)
	{
		super.initialize(p_renderer, p_view);
		VBox box = cast(VBox)getChild();

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
	}
}