// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module ui.style;

import lanlib.types : ivec2, svec2;

import ui.layout;
import ui.render;
import ui.view;

interface IRectMesh
{
	ushort[] create(UIView p_view, RealSize p_size);
	void resize(UIView p_view, ushort[] p_mesh, RealSize p_size);
	void translate(UIView p_view, ushort[] p_mesh, svec2 p_position);
	void change(UIView p_view, ushort[] p_mesh, SpriteId p_sprite);
}

final class SpriteQuad: IRectMesh
{
	private SpriteId id;

	public this(SpriteId p_id)
	{
		this.id = p_id;
	}

	public override ushort[] create(UIView p_view, RealSize p_size) nothrow
	{
		return p_view.addSpriteQuad(id);
	}

	public override void resize(UIView p_view, ushort[] p_mesh, RealSize p_size) nothrow
	{
		p_view.setQuadSize(p_mesh, p_size);
	}

	public override void translate(UIView p_view, ushort[] p_mesh, svec2 p_position) nothrow
	{
		p_view.translateQuad(p_mesh, p_position);
	}

	public override void change(UIView p_view, ushort[] p_mesh, SpriteId p_sprite) nothrow
	{
		p_view.changeSprite(p_mesh, p_sprite);
	}
}

struct ButtonStyle
{
	IRectMesh mesh;
	SpriteId normal;
	SpriteId pressed;
}

struct PanelStyle
{
	IRectMesh mesh;
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
}