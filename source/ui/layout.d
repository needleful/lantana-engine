// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module ui.layout;

import std.math;
debug import std.stdio;

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
		// Calculating the child dimensions and the resulting size of the whole thing is so confusing.
		// I'm sure I could break this down into something presentable with more work.

		IntrinsicSize childIntrinsic;
		// Child can be as small as it wants to be
		childIntrinsic.width.min = 0;
		childIntrinsic.height.min = 0;

		// The bounds for the anchor
		double parentWidth = p_intrinsic.width.max;

		// calculate the distances from the parent anchor to the edges
		double anchorToLeft = parentWidth * anchor.x;
		double anchorToRight = parentWidth*(1-anchor.x);

		// We're looking at two cases:
		// 		1. The child meets the left border (or both)
		//		2. The child meets the right border
		double childWidthMeetingLeft, childWidthMeetingRight;
		if(childAnchor.x == 0)
		{
			childWidthMeetingRight = anchorToRight;
			// invalid
			childWidthMeetingLeft = double.infinity;
		}
		else if(childAnchor.x == 1)
		{
			childWidthMeetingLeft = anchorToLeft;
			// invalid
			childWidthMeetingRight = double.infinity;
		}
		else
		{
			childWidthMeetingLeft = anchorToLeft/childAnchor.x;
			childWidthMeetingRight = anchorToRight/ (1-childAnchor.x);
		}

		// we need to select the maximum width for the child such that it's within the parent
		if(childWidthMeetingLeft <= parentWidth && childWidthMeetingRight <= parentWidth)
		{
			if(childWidthMeetingLeft > childWidthMeetingRight)
			{
				childIntrinsic.width.max = childWidthMeetingLeft;
			}
			else
			{
				childIntrinsic.width.max = childWidthMeetingRight;
			}
		}
		// I wish I knew how to remove this duplicated code
		else if(childWidthMeetingLeft <= parentWidth)
		{
			childIntrinsic.width.max = childWidthMeetingLeft;
		}
		else if(childWidthMeetingRight <= parentWidth)
		{
			childIntrinsic.width.max = childWidthMeetingRight;
		}
		else
		{
			// If this algorithm is correct, this should never be reached under any circumstances
			debug assert(false, "Cannot fit child width within parent");
			else return RealSize(0,0);
		}

		// We do the same process as above on the y axis
		double parentHeight = p_intrinsic.height.max;

		double anchorToBottom = parentHeight * anchor.y;
		double anchorToTop = parentHeight*(1-anchor.y);

		double childHeightMeetingBottom, childHeightMeetingTop;
		if(childAnchor.y == 0)
		{
			childHeightMeetingTop = anchorToTop;
			// invalid
			childHeightMeetingBottom = double.infinity;
		}
		else if(childAnchor.y == 1)
		{
			childHeightMeetingBottom = anchorToBottom;
			// invalid
			childHeightMeetingTop = double.infinity;
		}
		else
		{
			childHeightMeetingBottom = anchorToBottom/childAnchor.y;
			childHeightMeetingTop = anchorToTop/(1-childAnchor.y);
		}

		if(childHeightMeetingBottom <= parentHeight && childHeightMeetingTop <= parentHeight)
		{
			if(childHeightMeetingBottom > childHeightMeetingTop)
			{
				childIntrinsic.height.max = childHeightMeetingBottom;
			}
			else
			{
				childIntrinsic.height.max = childHeightMeetingTop;
			}
		}
		else if(childHeightMeetingBottom <= parentHeight)
		{
			childIntrinsic.height.max = childHeightMeetingBottom;
		}
		else if(childHeightMeetingTop <= parentHeight)
		{
			childIntrinsic.height.max = childHeightMeetingTop;
		}
		else
		{
			debug assert(false, "Cannot fit child height within parent");
			else return RealSize(0,0);
		}

		RealSize childSize = child.layout(p_renderer, childIntrinsic);

		child.position = ivec2(
			cast(int)(parentWidth*anchor.x - childSize.width*childAnchor.x),
			cast(int)(parentHeight*anchor.y - childSize.height*childAnchor.y));

		debug assert(child.position.x >= 0 && child.position.y >= 0, "Child extends beyond container bounds.");

		// Final size of the container
		RealSize result = RealSize(childSize.width + position.x, childSize.height + position.y);
		debug assert(!result.contains(RealSize(cast(int)parentHeight, cast(int)parentWidth)), "Child is larger than container.");

		return result;
	}
}

public class Padding : SingularContainer
{
	// Padding, in pixels
	int top, bottom, left, right;

	public this(Widget p_child, int p_padding) @nogc nothrow
	{
		child = p_child;

		top = p_padding;
		bottom = p_padding;
		left = p_padding;
		right = p_padding;
	}

	public this(Widget p_child, int p_vertical, int p_horizontal) @nogc nothrow
	{
		child = p_child;

		top = p_vertical;
		bottom = p_vertical;

		left = p_horizontal;
		right = p_horizontal;
	}

	public this(Widget p_child, int p_top, int p_bottom, int p_left, int p_right) @nogc nothrow
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
	SpriteId spriteId;
	// indeces into the UIRenderer vertex buffer
	ushort[] vertices;

	/// Currently no way for the UIRenderer to check if an image is loaded,
	/// so only use this if the image is going to be shown once on screen
	public this(UIRenderer p_renderer, string filename)
	{
		spriteId = p_renderer.loadSprite(filename);
		assert(spriteId != 0);
		textureSize = p_renderer.getSpriteSize(spriteId);
		init(p_renderer);
	}

	public this(UIRenderer p_renderer, SpriteId p_spriteId)
	{
		spriteId = p_spriteId;
		textureSize = p_renderer.getSpriteSize(spriteId);
		init(p_renderer);
	}

	private void init(UIRenderer p_renderer)
	{
		vertices = p_renderer.addSpriteQuad(spriteId);
		assert(vertices.length == 6);
	}

	public override RealSize layout(UIRenderer p_renderer, IntrinsicSize p_intrinsic) @nogc nothrow
	{
		// TODO: respect the intrinsics
		RealSize result = textureSize;
		p_renderer.setQuadSize(vertices, result);
		return result;
	}

	public override void prepareRender(UIRenderer p_renderer, ivec2 p_pen) @nogc nothrow
	{
		svec2 p = svec(p_pen.x, p_pen.y);
		p_renderer.translateQuad(vertices, p);
	}
}

// TODO: implement
public class TextBox: LeafWidget
{
	string text;
	ushort[] vertices;
	bool textChanged;

	public this(UIRenderer p_renderer, string text)
	{
		// TODO: adding text to the renderer
	}

	public override RealSize layout(UIRenderer p_renderer, IntrinsicSize p_intrinsic) @nogc nothrow
	{
		if(textChanged)
		{
			// TODO: update text EBO in this case
		}
		// Then calculate the size of each glyph and word.  We insert line breaks between words to keep width.
		// This is the only element that can overflow.

		return RealSize(0,0);
	}

	public override void prepareRender(UIRenderer p_renderer, ivec2 p_pen) @nogc nothrow
	{
		// TODO: translation of quads
	}

	public void setText(string p_text)
	{
		text = p_text;
		textChanged = true;
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
		if(p_max < p_min)
		{
			p_max = p_min;
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
