// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module editor.graph;

import std.conv;
import std.format;

import gl3n.linalg : vec3;

import lanlib.types;
import lanlib.util.array;
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
		SpriteId lineFocused;
	}
	Dialog dialog;

	TextBox tag;

	TextInput message, time, requirements, effects;

	VBox box;
	// Press this to create new responses
	Button sendButton;

	ivec2 lineStart, lineEnd;

	RealSize size;

	DialogNode[] responses;
	/// Lines to responses
	Line[] lines;

	// For dragging the window around
	InteractibleId bar;

	bool pressed;

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
		dialog.pauseTime = time.text.to!float();

		dialog.setRequirements(cast(string)requirements.text);
		dialog.setEffects(cast(string)effects.text);
		dialog.message = message.text.dup();
	}

	public override void initialize(UIRenderer p_renderer, UIView p_view)
	{
		super.initialize(p_renderer, p_view);

		HBox hb = cast(HBox)getChild();
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

		hb.addChild(new Spacer(RealSize(12)));
		hb.addChild(box);
		hb.addChild(sendButton);

		tag = new TextBox(dialog.getTag());

		message = new TextInput(512, dialog.message);
		requirements = new TextInput(256, dialog.getRequirements());
		effects = new TextInput(256, dialog.getEffects());
		time = new TextInput(16, format("%s", dialog.pauseTime));

		box.addChild(tag);
		box.addChild(new HBox([
			new TextBox("Pause Time:").withBounds(Bounds(120), Bounds.none), 
			time])
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

	public override void focus()
	{
		foreach(line; lines)
		{
			line.setSprite(DialogNode.lineFocused);
		}
	}
	public override void unfocus() 
	{
		if(pressed)
		{
			tag.setColor(view.renderer.style.defaultFontColor);
			// Call layout() properly to fix anything prepareRender() missed
			view.requestUpdate();
			pressed = false;
		}
		foreach(line; lines)
		{
			line.setSprite(view.renderer.style.line);
		}
	}
	public override void interact()
	{
		pressed = true;
		tag.setColor(vec3(1));
	}

	public override void drag(ivec2 p_dragAmount)
	{
		if(p_dragAmount.x == 0 && p_dragAmount.y == 0)
		{
			return;
		}
		auto hb = cast(HBox)getChild();
		// Rect widgets calculate their vertex positions in layout(),
		// and translate those vertices in prepareRender().
		// Because dragging skips layout(), we need to un-translate the verts
		panel.prepareRender(-dialog.edit_position - panel.position);
		sendButton.prepareRender(-dialog.edit_position -hb.position -sendButton.position);

		position += p_dragAmount;
		dialog.edit_position += p_dragAmount;
		prepareRender(dialog.edit_position);
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
		if(newResponseLine is null)
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
		}
		else
		{
			newResponseLine.start = Thunk!ivec2(()
			{
				return lineStart;
			});
			newResponseLine.setVisible(true);
		}
		if(view)
		{
			newResponseLine.initialize(view.renderer, view);
			newResponseLine.prepareRender(ivec2(0));
		}
		lines ~= newResponseLine;

	}

	public void createResponseEnd()
	{
		DialogNode response = null;
		InteractibleId focus;
		if(view.getFocusedObject(mousePosition, focus, priority()))
		{
			DialogNode focused = cast(DialogNode) view.getInteractible(focus);
			if(focused && responses.indexOf(focused) == -1)
			{
				response = focused;
				import std.stdio : writeln;
				writeln("Adding to existing dialogNode: %s", response.dialog.getTag());
			}
		}

		if(response is this)
		{
			newResponseLine.setVisible(false);
			newResponseLine.prepareRender(ivec2(0));
			lines = lines[0..$-1];
			return;
		}

		if(response is null)
		{
			auto d = new Dialog("Put your text here!", 0.75, []);
			d.edit_position = newResponseLine.end();
			response = new DialogNode(view.renderer, d);
			parent.addChild(response);
		}

		responses ~= response;
		dialog.responses ~= response.dialog;
		newResponseLine.end = Thunk!ivec2(&response.lineEnd);
		newResponseLine.prepareRender(ivec2(0));

		newResponseLine = null;
	}
}