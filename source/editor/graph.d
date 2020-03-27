// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module editor.graph;

import std.conv;
import std.format;

import gl3n.linalg : vec3;

import lanlib.types;
import game.dialog;
import ui;

version(lantana_editor)
final class DialogNode : Padding, Interactible
{
	static
	{
		Line newResponseLine;
		ivec2 mousePosition;
		MultiContainer parent;
		DialogNode[] nodes;
	}
	Dialog dialog;

	TextBox tag;

	TextInput message, date, time, requirements, effects;

	VBox box;
	// Press this to create new responses
	Button sendButton;
	// Press this for reasons
	Button recieveButton;

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

		super(new HBox([], 12, Alignment.CENTER), Pad(6), new ImageBox(p_ui, color(120, 120, 255, 80), RealSize(1)));
		dialog = p_dialog;
		position = dialog.edit_position;
		nodes ~= this;
	}

	public void updateDialog()
	{
		dialog.edit_position = position;

		dialog.date = date.text.dup();
		dialog.pauseTime = time.text.to!float();

		dialog.requirements = requirements.text.dup();
		dialog.effects = effects.text.dup();
		dialog.message = message.text.dup();
	}

	public override void initialize(UIRenderer p_renderer, UIView p_view)
	{
		super.initialize(p_renderer, p_view);

		HBox hb = cast(HBox)getChild();
		recieveButton = new Button(
			p_renderer, new Spacer(RealSize(0, 100)), (Widget)
			{
			});
		sendButton = new Button(
			p_renderer, new Spacer(RealSize(0, 100)), 
			(Widget)
			{
				createResponseEnd();
			});
		sendButton.onPressed = (Widget)
			{
				createResponseStart();
			};
		sendButton.onDragged = (ivec2 _)
		{
			if(newResponseLine)
				newResponseLine.prepareRender(ivec2(0));
		};

		hb.addChild(recieveButton);
		hb.addChild(box);
		hb.addChild(sendButton);

		tag = new TextBox(dialog.getTag());

		message = new TextInput(1024, dialog.message);
		requirements = new TextInput(512, dialog.requirements);
		effects = new TextInput(512, dialog.effects);
		date = new TextInput(64, dialog.date);
		time = new TextInput(32, format("%f", dialog.pauseTime));

		box.addChild(tag);
		box.addChild(new HBox([
			new TextBox("Pause Time:").withBounds(Bounds(120), Bounds.none), 
			time])
		);
		box.addChild(new HBox([
			new TextBox("Date:").withBounds(Bounds(120), Bounds.none),
			date])
		);
		box.addChild(new HBox([
			new TextBox("Requirements:").withBounds(Bounds(120, double.infinity), Bounds.none),
			requirements])
		);
		box.addChild(new HBox([
			new TextBox("Effects:").withBounds(Bounds(120), Bounds.none),
			effects])
		);

		box.addChild(new TextBox("Message:"));
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
		auto line = new Line(
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

	public void createResponseStart()
	{
		newResponseLine = new Line(
			Thunk!ivec2(()
			{
				return lineStart;
			}),
			Thunk!ivec2(()
			{
				return mousePosition - view.getTranslation();
			}));

		if(view)
		{
			newResponseLine.initialize(view.renderer, view);
			newResponseLine.prepareRender(ivec2(0));
		}
		lines ~= newResponseLine;

	}

	public void createResponseEnd()
	{
		// TODO: how to handle existing dialog?
		auto d = new Dialog("Put your text here!", 0, []);
		d.edit_position = newResponseLine.end();
		dialog.responses ~= d;

		auto response = new DialogNode(view.renderer, d);
		responses ~= response;
		newResponseLine.end = Thunk!ivec2(&response.lineEnd);
		parent.addChild(response);
	}
}