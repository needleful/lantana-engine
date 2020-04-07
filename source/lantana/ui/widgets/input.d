// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.ui.widgets.input;

import gl3n.linalg: vec2, vec3;
import lantana.types;
import lantana.ui.interaction;
import lantana.ui.render;
import lantana.ui.view;
import lantana.ui.widgets;

public class Button: MultiContainer, Interactible
{
	public Interactible.Callback onPressed, onReleased;
	public Interactible.DragCallback onDragged = null;
	private InteractibleId id;
	private bool pressed;
	private HFlags flags;

	public this(UIRenderer p_renderer, Widget p_child, Interactible.Callback p_onReleased, HFlags p_flags = HFlags.init)
	{
		children.reserve(2);
		children ~= p_renderer.style.button.mesh.create(p_renderer);
		children ~= new Padding(p_child, p_renderer.style.button.pad);
		onReleased = p_onReleased;

		children[0].position = ivec2(0,0);
		children[1].position = ivec2(0,0);
		flags = p_flags;
	}

	public override void initialize(UIRenderer p_renderer, UIView p_view)
	{
		super.initialize(p_renderer, p_view);
		id = p_view.addInteractible(this);
	}

	public override RealSize layout(SizeRequest p_request) 
	{
		if(!visible || p_request == SizeRequest.hide)
		{
			view.setInteractSize(id, RealSize(0));
			return layoutEmpty();
		}
		SizeRequest req = p_request.constrained(absoluteWidth, absoluteHeight);
		SizeRequest childReq = req;
		if(!flags[HFlag.Expand])
		{
			childReq.height.min = 0;
			childReq.width.min = 0;
		}

		RealSize childSize = children[1].layout(childReq);
		RealSize res = childSize.constrained(req);

		if(flags[HFlag.Center])
		{
			RealSize diff = res - childSize;
			children[1].position = ivec2(diff.width, diff.height)/2;
		}

		children[0].layout(SizeRequest(res));

		view.setInteractSize(id, res);
		return res;
	}

	public override void prepareRender(ivec2 p_pen) 
	{
		view.setInteractPosition(id, p_pen);
		super.prepareRender(p_pen);
	}

	public override short priority()
	{
		return 10;
	}
	/// Interactible methods
	public override void focus()
	{
		(cast(RectWidget)children[0]).setSprite(view.renderer.style.button.focused);
	}

	public override void unfocus()
	{
		(cast(RectWidget)children[0]).setSprite(view.renderer.style.button.normal);
	}

	public override void release()
	{
		(cast(RectWidget)children[0]).setSprite(view.renderer.style.button.focused);
		onReleased(this);
	}

	public override void drag(ivec2 p_drag) 
	{
		if(onDragged)
			onDragged(p_drag);
	}

	public override void interact()
	{
		(cast(RectWidget)children[0]).setSprite(view.renderer.style.button.pressed);
		if(onPressed) onPressed(this);
	}

	public Widget getChild()
	{
		return (cast(Container)children[1]).getChildren()[0];
	}
}

final class TextInput : Widget, Interactible
{
	FontId font;
	char[] text;
	TextId mesh;

	ushort capacity;
	RectWidget cursor;
	ushort index = 0;

	InteractibleId interactible;

	public this(uint p_capacity = 256, string p_text = "")
	{
		text.reserve(p_capacity);
		capacity = cast(ushort)p_capacity;
		text.length = p_text.length;
		text[] = p_text[];
		index = cast(ushort)(text.length);
		withBounds(Bounds(40,double.infinity), Bounds(20, double.infinity));
	}

	public override void initialize(UIRenderer p_renderer, UIView p_view)
	{
		super.initialize(p_renderer, p_view);

		font = p_renderer.style.defaultFont;

		mesh = p_view.addTextMesh(font, cast(string)text, cast(int)text.capacity);
		view.setTextVisiblePercent(mesh, 1);
		view.setTextColor(mesh, p_renderer.style.textInput.normal);

		cursor = new ImageBox(
			p_renderer.style.textInput.cursor
		);
		cursor.initialize(p_renderer, p_view);
		cursor.setVisible(false);

		interactible = p_view.addInteractible(this);
	}

	public override RealSize layout(SizeRequest p_request) 
	{
		if(!visible || p_request == SizeRequest.hide)
		{
			view.setTextVisiblePercent(mesh, 0f);
			return RealSize(0);
		}
		view.setTextVisiblePercent(mesh, 1);
		SizeRequest req = p_request.constrained(absoluteWidth, absoluteHeight);
		
		view.setTextMesh(
			mesh, font, cast(string) text,
			req.width, true);

		cursor.layout(SizeRequest(Bounds(2), Bounds(view.renderer.lineHeight(font))));
		cursor.position = view.getCursorPosition(mesh, cast(string) text, index);

		RealSize textSize = view.textBoundingBox(mesh);
		view.setInteractSize(interactible, textSize.constrained(req));

		return textSize;
	}

	public override void prepareRender(ivec2 p_pen) 
	{
		view.setInteractPosition(interactible, p_pen);
		view.translateTextMesh(mesh, p_pen);
		cursor.prepareRender(cursor.position + p_pen);
	}

	public void cursorLeft()
	{
		if(index <= 0)
		{
			index = 0;
			return;
		}
		index--;
		view.requestUpdate();
	}

	public void cursorRight()
	{
		if(index >= text.length)
		{
			index = cast(ushort)(text.length);
			return;
		}
		index ++;
		view.requestUpdate();
	}

	public void insert(char c)
	{
		insert([c]);
	}

	public void insert(char[] str)
	{
		import std.format;
		if(text.length + str.length > capacity)
		{
			return;
		}
		text.length += str.length;

		for(ulong i = text.length-1; i > index + str.length-1; i--)
		{
			text[i] = text[i-str.length];
		}

		text[index..index+str.length] = str[];
		index += str.length;

		view.requestUpdate();
	}

	public void backSpace()
	{
		if(index == 0)
		{
			return;
		}

		for(ulong i = index; i < text.length; i++)
		{
			text[i-1] = text[i];
		}
		text.length --;
		index -- ;
		view.requestUpdate();
	}

	public string getTextCopy()
	{
		return cast(string) text.dup();
	}

	public override short priority()
	{
		return 5;
	}
	/// Interactible methods
	public override void focus(){}
	public override void unfocus(){}
	public override void release(){}
	public override void drag(ivec2 _) {}

	public override void interact()
	{
		view.renderer.setTextFocus(this);
		view.setTextColor(mesh, view.renderer.style.textInput.focused);
		cursor.setVisible(true);
	}

	public void removeTextFocus()
	{
		cursor.setVisible(false);
		view.setTextColor(mesh, view.renderer.style.textInput.normal);
	}
}