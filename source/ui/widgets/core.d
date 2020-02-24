// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module ui.widgets.core;

import lanlib.types : ivec2;
import ui.layout;
import ui.render;
import ui.view;

// The basic system is inspired by Flutter
// Flutter data layout:
// Construct a tree.
//		From root to leaves, apply constraints
//		from leaves to root, calculate sizes
//	Child knows size, parent knows position
//	This means the child's size cannot depend on its position

/// Base UI class.  All UI elements are Widgets
public abstract class Widget
{
	UIView view;
	bool visible = true;

	/// Pixel position of the widget, from the bottom left of the screen to the bottom left of the widget
	/// As a rule, the position should ONLY be read by the parent
	public ivec2 position;

	/// Force the Widget to be within these bounds.  Overrides the parent request.
	/// This should be used sparingly!  It can break things!
	protected Bounds absoluteWidth = Bounds.none;
	protected Bounds absoluteHeight = Bounds.none;

	/// Two-phase constructor.  This is called when the Widget is put into the tree
	public void initialize(UIRenderer p_renderer, UIView p_view)
	{
		view = p_view;
	}

	/// First phase of layout, taking some SizeRequest (bounds), and providing the real size of the object
	/// Parents calculate the position of their children
	public abstract RealSize layout(SizeRequest p_request);

	/// Second phase of layout: this is 
	public abstract void prepareRender(ivec2 p_pen);

	public Widget withBounds(Bounds p_width, Bounds p_height)
	{
		absoluteWidth = p_width;
		absoluteHeight = p_height;
		return this;
	}

	public void setVisible(bool p_vis)
	{
		if(p_vis == visible) return;
		visible = p_vis;
		view.requestUpdate();
	}
	
	public final bool isVisible()
	{
		return visible;
	}
}

public abstract class Container : Widget
{
	public abstract Widget[] getChildren();

	public override void initialize(UIRenderer p_renderer, UIView p_view)
	{
		super.initialize(p_renderer, p_view);
		foreach(child; getChildren())
		{
			child.initialize(p_renderer, p_view);
		}
	}

	public override void prepareRender(ivec2 p_pen)
	{
		foreach(child; getChildren())
		{
			child.prepareRender(child.position + p_pen);
		}
	}
}

public abstract class MultiContainer : Container
{
	protected Widget[] children;

	public final override Widget[] getChildren() 
	{
		return children;
	}

	protected final RealSize layoutEmpty()
	{
		foreach(child; getChildren())
		{
			child.layout(SizeRequest.hide);
		}
		return RealSize(0);
	}
}

public abstract class SingularContainer: Container
{
	protected Widget child;

	public final override Widget[] getChildren() 
	{
		return (&child)[0..1];
	}

	public final const(Widget) getChild() 
	{
		return child;
	}

	protected final RealSize layoutEmpty()
	{
		child.layout(SizeRequest.hide);
		return RealSize(0);
	}
}

public abstract class RectWidget : Widget
{
	public void setSprite(SpriteId p_sprite);

	public void setPosition(ivec2 p_position);
}