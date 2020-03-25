// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module ui.widgets.input;

import gl3n.linalg: vec2, vec3;
import lanlib.types : ivec2, AlphaColor;
import ui.interaction;
import ui.layout;
import ui.render;
import ui.view;
import ui.widgets;

public class Button: MultiContainer, Interactible
{
	public Interactible.Callback onPressed;
	private InteractibleId id;
	private bool pressed;
	private HFlags flags;

	public this(UIRenderer p_renderer, Widget p_child, Interactible.Callback p_onPressed, HFlags p_flags = HFlags.init)
	{
		children.reserve(2);
		children ~= p_renderer.style.button.mesh.create(p_renderer);
		children ~= new Padding(p_child, p_renderer.style.button.pad);
		onPressed = p_onPressed;

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
		return 1;
	}
	/// Interactible methods
	public override void focus()
	{
		(cast(RectWidget)children[0]).setSprite(view.renderer.style.button.focused);
	}

	public override void unfocus()
	{
		if(pressed) onPressed(this);
		pressed = false;
		(cast(RectWidget)children[0]).setSprite(view.renderer.style.button.normal);
	}

	public override void drag(ivec2 _) {}

	public override void interact()
	{
		pressed = true;
		(cast(RectWidget)children[0]).setSprite(view.renderer.style.button.pressed);
	}

	public Widget getChild()
	{
		return (cast(Container)children[1]).getChildren()[0];
	}
}

final class TextInput : Widget
{
	FontId font;
	char[] text;
	TextId mesh;
	vec3 color;

	RectWidget cursor;
	AlphaColor cursorColor;
	ushort index = 0;

	public this(AlphaColor p_cursor,
		uint p_capacity = 256, string p_text = "",
		FontId p_font = FontId.invalid, vec3 p_color = vec3(-1))
	{
		text.reserve(p_capacity);
		text.length = p_text.length;
		text[] = p_text[];
		font = p_font;
		color = p_color;
		cursorColor = p_cursor;
		index = cast(ushort)(text.length);
	}

	public override void initialize(UIRenderer p_renderer, UIView p_view)
	{
		super.initialize(p_renderer, p_view);
		if(color == vec3(-1))
		{
			color = p_renderer.style.defaultFontColor;
		}
		if(font == FontId.invalid)
		{
			font = p_renderer.style.defaultFont;
		}

		mesh = p_view.addTextMesh(font, cast(string)text, cast(int)text.capacity);
		view.setTextVisiblePercent(mesh, 1);
		view.setTextColor(mesh, color);

		cursor = new ImageBox(
			p_renderer,
			cursorColor,
			RealSize(1, p_renderer.lineHeight(font))
		);
		cursor.initialize(p_renderer, p_view);
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

		cursor.layout(SizeRequest(Bounds(2), Bounds.none));
		cursor.position = view.getCursorPosition(mesh, cast(string) text, index);

		return view.textBoundingBox(mesh);
	}

	public override void prepareRender(ivec2 p_pen) 
	{
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
		import std.format;
		text.length ++;

		for(ulong i = text.length-1; i > index; i--)
		{
			text[i] = text[i-1];
		}

		text[index] = c;
		index ++;

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
		index--;
		view.requestUpdate();
	}
}