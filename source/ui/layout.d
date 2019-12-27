// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module ui.layout;

import std.math;

import gl3n.linalg: vec2, vec3, Vector;
import lanlib.types;
import ui.render;

// The basic system is inspired by Flutter
// Flutter data layout:
// Construct a tree.
//		From root to leaves, apply constraints
//		from leaves to root, calculate sizes
// Cartesian coordinates (width/height)
//		Intrinsic sizes (max/min dimensions)
//		Intrinsics (min and max) determined by the parent
//		Paradigms: Fixed size; Width-In, Height-Out; Height-in, Width-Out; 
//		Child knows size, parent knows position
//		This means the child's size cannot depend on its position
// Some children want a particular size, some are flexible (varying flex factors)
//		Flex calculation: FlexFactor * SpacePerFlex
//		Parent passes its own constraints to the children (at least)
//		For max size, use Infinity to indicate no preference
// Relayout boundaries: conditions where a widget will never need a relayout
//		Tight constraints: sized determined by parent, will not change size for children
//		Parent Uses Size: the parent does/doesn't care about the child's size for positioning or sizing itself
//		Sized By Parent: like tight constraints, but for widgets that always expand/shrink
// Create separate walks along the trees for layout and drawing
// Repaint boundaries: determine what objects will often need repainting and separate them out

/// Base UI class.  All UI elements are Widgets
public abstract class Widget
{
	/// Pixel position of the widget, from the bottom left of the screen to the bottom left of the widget
	/// As a rule, the position should ONLY be read by the parent
	public ivec2 position;

	/// First phase of layout, taking some IntrinsicSize (bounds), and providing the real size of the object
	/// Parents calculate the position of their children
	public abstract RealSize layout(UIRenderer p_renderer, IntrinsicSize p_intrinsic) @nogc nothrow;

	/// Second phase of layout: this is 
	public void prepareRender(UIRenderer p_renderer, ivec2 p_pen) @nogc nothrow
	{
		foreach(child; getChildren())
		{
			child.prepareRender(p_renderer, child.position + p_pen);
		}
	}

	public abstract Widget[] getChildren() @nogc nothrow;
}

public class Modal : Widget
{
	public Widget[] pages;
	public uint pageIndex;

	public const(Widget[]) getPages() const @nogc nothrow
	{
		return pages;
	}

	public override RealSize layout(UIRenderer p_renderer, IntrinsicSize p_intrinsic) @nogc nothrow
	{
		auto currentPage = pages[pageIndex];
		RealSize returnValue;

		// Lay out each page to reduce work when switching pages.
		foreach(page; pages)
		{
			page.position = ivec2(0);
			if(&page == &currentPage)
			{
				returnValue = page.layout(p_renderer, p_intrinsic);
			}
			else 
			{
				page.layout(p_renderer, p_intrinsic);
			}
		}
		return returnValue;
	}

	public override Widget[] getChildren() @nogc nothrow
	{
		return pages;
	}

	public override void prepareRender(UIRenderer p_renderer, ivec2 p_pen) @nogc nothrow
	{
		auto page = pages[pageIndex];
		page.prepareRender(p_renderer, page.position + p_pen);
	}
}

/// Provides no layout hints.  All widgets are laid out in the same space and position
public class HodgePodge : Widget
{
	public Widget[] children;


	public this(Widget[] p_children) @nogc nothrow
	{
		children = p_children;
	}

	public override RealSize layout(UIRenderer p_renderer, IntrinsicSize p_intrinsic) @nogc nothrow
	{
		ivec2 top_right;

		foreach(child; children)
		{
			child.position = ivec2(0,0);
			RealSize csize = child.layout(p_renderer, p_intrinsic);

			// Calculating the bounding box for the hodgepodge
			top_right = ivec2(cast(int) fmax(csize.width, top_right.x), cast(int) fmax(csize.height, top_right.y));
		}

		return RealSize(top_right.x, top_right.y);
	}

	public override Widget[] getChildren() @nogc nothrow
	{
		return children;
	}
}

public abstract class SingularContainer: Widget
{
	Widget child;

	public override Widget[] getChildren() @nogc nothrow
	{
		return (&child)[0..1];
	}
}

public abstract class LeafWidget : Widget
{
	public override Widget[] getChildren() @nogc nothrow
	{
		return [];
	}
} 


/// Anchor the widget to a specific point
public class Anchor: SingularContainer
{
	// Normalized coordinates, (0,0) is bottom left of the container
	vec2 anchor;
	// Normalized coordinates of anchor for child element.  This is what's moved to the anchor
	vec2 childAnchor;

	public this(Widget p_child, vec2 p_anchor, vec2 p_childAnchor = vec2(0,0)) @nogc nothrow
	{
		child = p_child;
		child.position = ivec2(0,0);

		anchor = p_anchor;
		childAnchor = p_childAnchor;
	}

	public override RealSize layout(UIRenderer p_renderer, IntrinsicSize p_intrinsic) @nogc nothrow
	{
		RealSize rs = RealSize(cast(int)p_intrinsic.width.max, cast(int)p_intrinsic.height.max);

		// determine distance from boundaries in pixels.  This will be the max child size. 
		vec2 baseAnchor = anchor + childAnchor;
		vec2 absAnchor = vec2(fmin(baseAnchor.x, 1 - baseAnchor.x), fmin(baseAnchor.y, 1 - baseAnchor.y));

		double widthToSide = p_intrinsic.width.max * absAnchor.x;
		double heightToSide = p_intrinsic.height.max * absAnchor.y;

		RealSize childSize = child.layout(p_renderer, p_intrinsic);

		// Compute the position of the child, in pixel coordinates relative to the bottom left of this widget, based on the anchor
		child.position = ivec2(
			cast(int) (anchor.x*rs.width - childAnchor.x*childSize.width),
			cast(int) (anchor.y*rs.height - childAnchor.y*childSize.height)
		);
		return rs;
	}
}

public class Padding : SingularContainer
{
	// Padding, in pixels
	int top, bottom, left, right;

	public this(Widget p_child, int p_top = 0, int p_bottom = 0, int p_left = 0, int p_right = 0) @nogc nothrow
	{
		child = p_child;

		top = p_top;
		bottom = p_bottom;
		left = p_left;
		right = p_right;
	}

	public override RealSize layout(UIRenderer p_renderer, IntrinsicSize p_intrinsic) @nogc nothrow
	{
		double maxWidth = p_intrinsic.width.max - (left + right);
		double maxHeight = p_intrinsic.height.max - (top + bottom);

		// Constrain child to the full box (or infinity)
		IntrinsicSize childIntrinsic = IntrinsicSize(Bounds(maxWidth, maxWidth), Bounds(maxHeight, maxHeight));
		RealSize csize = child.layout(p_renderer, childIntrinsic);
		child.position = ivec2(left, bottom);

		return RealSize(csize.width + left + right, csize.height + top + bottom);
	}
}

public class ImageBox : LeafWidget
{
	RealSize textureSize;
	UIMesh spriteQuad;
	SpriteId spriteId;

	public this(UIRenderer p_renderer, SpriteId p_spriteId)
	{
		spriteId = p_spriteId;
		textureSize = p_renderer.getSpriteSize(spriteId);
		// TODO: get UI mesh
	}

	public this(UIRenderer p_renderer, Texture!AlphaColor p_texture)
	{
		textureSize = p_texture.size;
		// TODO: prevent duplicates of the same image?
		spriteId = p_renderer.addSprite(p_texture);
		assert(spriteId != 0);
	}

	public override RealSize layout(UIRenderer p_renderer, IntrinsicSize p_intrinsic) @nogc nothrow
	{
		int desiredWidth = cast(int) textureSize.width;
		int desiredHeight = cast(int) textureSize.height;

		if(p_intrinsic.inBounds(desiredWidth, desiredHeight))
		{
			return RealSize(desiredWidth, desiredHeight);
		}

		// Have to resize the image
		double relativeMaxWidth = p_intrinsic.width.max / desiredWidth;
		double relativeMaxHeight = p_intrinsic.height.max / desiredHeight;

		double relativeMinWidth = p_intrinsic.width.min / desiredWidth;
		double relativeMinHeight = p_intrinsic.height.min / desiredHeight;

		// TODO: fix this
		return RealSize(desiredWidth, desiredHeight);
	}
}

public struct IntrinsicSize
{
	Bounds width;
	Bounds height;

	public this(Bounds p_width, Bounds p_height) @nogc nothrow
	{
		width = p_width;
		height = p_height;
	}

	const public bool inBounds(int p_width, int p_height) @nogc nothrow
	{
		return width.contains(p_width) && height.contains(p_height);
	}
}

public struct Bounds
{
	double min;
	double max;

	this(double p_min, double p_max = -double.infinity) @nogc nothrow
	{
		if(p_min > p_max)
		{
			p_min = p_max;
		}
		min = p_min;
		max = p_max;
	}

	this(Bounds p_copy) @nogc nothrow
	{
		min = p_copy.min;
		max = p_copy.max;
	}

	const public bool contains(double value) @nogc nothrow
	{
		return min <= value && max >= value;
	}
}

public struct RealSize
{
	int width;
	int height;

	public this(int p_width, int p_height) @nogc nothrow
	{
		width = p_width;
		height = p_height;
	}

	public RealSize opBinary(string op)(RealSize rhs) @nogc nothrow
	{
		static if(op == "+")
			return RealSize(width + rhs.width, height + rhs.height);
		static if(op == "-")
			return RealSize(width - rhs.width, height - rhs.height);
		else
			assert(false, "No operator "~op~" between RealSize objects");
	}

	bool opEquals(RealSize rhs) @nogc nothrow const
	{
		return width == rhs.width && height == rhs.height;
	}

	bool contains(RealSize rhs) @nogc nothrow const
	{
		return width >= rhs.width && height >= rhs.height;
	}
}
