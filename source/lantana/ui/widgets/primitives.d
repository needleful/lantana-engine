// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.ui.widgets.primitives;

import lantana.math.vectors;
import lantana.types;

import lantana.ui.render;
import lantana.ui.view;
import lantana.ui.widgets;

public class Line : Widget
{
	Thunk!iVec2 start;
	Thunk!iVec2 end;
	float thickness;

	SpriteId sprite;
	MeshRef mesh;

	public this(Thunk!iVec2 p_start, Thunk!iVec2 p_end, float p_thickness = 2.5)
	{
		start = p_start;
		end = p_end;
		thickness = p_thickness;
	}

	public override void initialize(UIRenderer p_renderer, UIView p_view)
	{
		super.initialize(p_renderer, p_view);
		sprite = p_renderer.style.line;
		mesh = view.addSpriteQuad(sprite);
	}

	public override RealSize layout(SizeRequest _)
	{
		return RealSize(0);
	}

	public override void prepareRender(iVec2 p_pen)
	{
		if(!isVisible())
			view.setLineQuad(mesh, start(), start(), 0);
		else
			view.setLineQuad(mesh, start(), end(), thickness);
	}

	public void setSprite(SpriteId p_sprite)
	{
		view.setSprite(mesh, p_sprite);
	}
}