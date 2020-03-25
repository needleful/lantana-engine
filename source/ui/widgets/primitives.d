// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module ui.widgets.primitives;

import lanlib.types;

import ui.layout;
import ui.render;
import ui.view;
import ui.widgets;

public class Line : Widget
{
	Thunk!ivec2 start;
	Thunk!ivec2 end;
	float thickness;

	AlphaColor color;

	SpriteId sprite;
	MeshRef mesh;

	public this(AlphaColor p_color, Thunk!ivec2 p_start, Thunk!ivec2 p_end, float p_thickness = 2.5)
	{
		color = p_color;
		start = p_start;
		end = p_end;
		thickness = p_thickness;
	}

	public override void initialize(UIRenderer p_renderer, UIView p_view)
	{
		super.initialize(p_renderer, p_view);
		sprite = p_renderer.addSinglePixel(color);
		mesh = view.addSpriteQuad(sprite);
	}

	public override RealSize layout(SizeRequest _)
	{
		return RealSize(0);
	}

	public override void prepareRender(ivec2 p_pen)
	{
		view.setLineQuad(mesh, start(), end(), thickness);
	}
}