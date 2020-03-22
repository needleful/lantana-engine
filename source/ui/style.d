// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module ui.style;

import gl3n.linalg : vec3;

import lanlib.types : ivec2, svec2;

import ui.layout;
import ui.render;
import ui.view;
import ui.widgets;

interface IRectStyle
{
	RectWidget create(UIRenderer p_renderer) ;
}

final class SpriteQuadStyle: IRectStyle
{
	private SpriteId id;

	public this(SpriteId p_id) 
	{
		this.id = p_id;
	}

	public override RectWidget create(UIRenderer p_renderer) 
	{
		return new ImageBox(id);
	}
}

final class PatchRectStyle : IRectStyle
{
	private SpriteId id;
	private Pad pad;

	public this(SpriteId p_id, Pad p_pad)
	{
		id = p_id;
		pad = p_pad;
	}

	public override RectWidget create(UIRenderer p_renderer) 
	{
		return new PatchRect(id, pad);
	}
}

struct ButtonStyle
{
	IRectStyle mesh;
	Pad pad;
	SpriteId normal;
	SpriteId focused;
	SpriteId pressed;
}

struct PanelStyle
{
	IRectStyle mesh;
	SpriteId sprite;
}

struct ScrollbarStyle
{
	PanelStyle trough;
	SpriteId upArrow, downArrow;
	ubyte width;
}

final class UIStyle
{
	public ButtonStyle button;
	public PanelStyle panel;
	public ScrollbarStyle scrollbar;
	public FontId defaultFont;
	public vec3 defaultFontColor;
}