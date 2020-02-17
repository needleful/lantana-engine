// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module ui.containers;

import std.math;
debug import std.stdio;

import gl3n.linalg: vec2;

import lanlib.types;
import ui.interaction;
import ui.layout;
import ui.render;
import ui.view;

public abstract class SingularContainer: Widget
{
	Widget child;

	public override Widget[] getChildren() nothrow
	{
		return (&child)[0..1];
	}

	public const(Widget) getChild() nothrow
	{
		return child;
	}
}

public abstract class Container : Widget
{
	Widget[] children;

	public override Widget[] getChildren() nothrow
	{
		return children;
	}
}


/// Provides no layout hints.  All widgets are laid out in the same space and position
public class HodgePodge : Container
{
	public this(Widget[] p_children) nothrow
	{
		children = p_children;
	}

	public override RealSize layout(UIView p_renderer, SizeRequest p_request) nothrow
	{
		SizeRequest request = p_request.constrained(absoluteWidth, absoluteHeight);

		ivec2 top_right;

		foreach(child; children)
		{
			child.position = ivec2(0,0);
			RealSize csize = child.layout(p_renderer, request);

			// Calculating the bounding box for the hodgepodge
			top_right = ivec2(cast(int) fmax(csize.width, top_right.x), cast(int) fmax(csize.height, top_right.y));
		}

		return RealSize(top_right.x, top_right.y);
	}
}

/// Relative positioning with no size constraints on object
public class Positioned: SingularContainer
{
	vec2 anchor;
	vec2 childAnchor;

	public this(Widget p_child, vec2 p_anchor, vec2 p_childAnchor) nothrow
	{
		child = p_child;
		anchor = p_anchor;
		childAnchor = p_childAnchor;
	}

	public override RealSize layout(UIView p_renderer, SizeRequest p_request)
	{
		SizeRequest childRequest = SizeRequest(absoluteWidth, absoluteHeight);

		RealSize childSize = child.layout(p_renderer, childRequest);

		RealSize parent = RealSize(cast(int) p_request.width.max, cast(int) p_request.height.max);

		child.position = ivec2(
			cast(int)(parent.width*anchor.x - childSize.width*childAnchor.x),
			cast(int)(parent.height*anchor.y - childSize.height*childAnchor.y));

		return parent;
	}
}

/// Anchor the widget to a specific point
public class Anchor: SingularContainer
{
	// Normalized coordinates, (0,0) is bottom left of the container
	vec2 anchor;
	// Normalized coordinates of anchor for child element.  This is what's moved to the anchor
	vec2 childAnchor;

	public this(Widget p_child, vec2 p_anchor, vec2 p_childAnchor = vec2(0,0)) nothrow
	{
		child = p_child;
		child.position = ivec2(0,0);

		anchor = p_anchor;
		childAnchor = p_childAnchor;
	}

	public override RealSize layout(UIView p_renderer, SizeRequest p_request) nothrow
	{
		SizeRequest request = p_request.constrained(absoluteWidth, absoluteHeight);
		// Calculating the child dimensions and the resulting size of the whole thing is so confusing.
		// I'm sure I could break this down into something presentable with more work.

		SizeRequest childIntrinsic;
		// Child can be as small as it wants to be
		childIntrinsic.width.min = 0;
		childIntrinsic.height.min = 0;

		// The bounds for the anchor
		double parentWidth = request.width.max;

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
		double parentHeight = request.height.max;

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

public class AnchoredBox : Container
{
	vec2 bottomLeft;
	vec2 topRight;

	public this(Widget[] p_children, vec2 p_bLeft, vec2 p_tRight)
	{
		children = p_children;
		bottomLeft = p_bLeft;
		topRight = p_tRight;
	}

	public override RealSize layout(UIView p_renderer, SizeRequest p_request)
	{
		// AnchoredBox forces its children to occupy the full box
		SizeRequest childRequest;

		vec2 vSize = topRight - bottomLeft;
		childRequest.width = Bounds(p_request.width.max * vSize.x);
		childRequest.height = Bounds(p_request.height.max * vSize.y);

		childRequest = childRequest.constrained(absoluteWidth, absoluteHeight);

		foreach(child; children)
		{
			child.position = ivec2(cast(int)(p_request.width.max*bottomLeft.x), cast(int)(p_request.height.max*bottomLeft.y));
			child.layout(p_renderer, childRequest);
		}

		return RealSize(cast(int) childRequest.width.max, cast(int) childRequest.height.max);
	}
}

public class Padding : SingularContainer
{
	// Padding, in pixels
	int top, bottom, left, right;

	public this(Widget p_child, int p_padding) nothrow
	{
		child = p_child;

		top = p_padding;
		bottom = p_padding;
		left = p_padding;
		right = p_padding;
	}

	public this(Widget p_child, int p_vertical, int p_horizontal) nothrow
	{
		child = p_child;

		top = p_vertical;
		bottom = p_vertical;

		left = p_horizontal;
		right = p_horizontal;
	}

	public this(Widget p_child, int p_top, int p_bottom, int p_left, int p_right) nothrow
	{
		child = p_child;

		top = p_top;
		bottom = p_bottom;
		left = p_left;
		right = p_right;
	}

	public override RealSize layout(UIView p_renderer, SizeRequest p_request) nothrow
	{
		SizeRequest request = p_request.constrained(absoluteWidth, absoluteHeight);

		double maxWidth = request.width.max - (left + right);
		double maxHeight = request.height.max - (top + bottom);

		// Constrain child to the full box (or infinity)
		SizeRequest childIntrinsic = SizeRequest(Bounds(maxWidth, maxWidth), Bounds(maxHeight, maxHeight));
		RealSize csize = child.layout(p_renderer, childIntrinsic);
		child.position = ivec2(left, bottom);

		return RealSize(csize.width + left + right, csize.height + top + bottom);
	}
}

class HBox: Container
{
	// Space between children
	int spacing;

	this(Widget[] p_children, int p_spacing = 0)
	{
		children = p_children;
		spacing = p_spacing;
	}

	public override RealSize layout(UIView p_renderer, SizeRequest p_request) nothrow
	{
		SizeRequest request = p_request.constrained(absoluteWidth, absoluteHeight);

		//TODO: respect intrinsics properly
		RealSize size;
		ivec2 pen = ivec2(0,0);
		foreach(child; children)
		{
			RealSize childSize = child.layout(p_renderer, request);
			child.position.x = pen.x;
			child.position.y = -childSize.height/2;

			size.width = pen.x + childSize.width;
			size.height = childSize.height > size.height? childSize.height: size.height;

			pen.x += childSize.width + spacing;
		}

		foreach(child; children)
		{
			child.position.y += size.height/2;
		}

		return size;
	}
}

class VBox: Container
{
	// Space between children
	int spacing;

	this(Widget[] p_children, int p_spacing = 0)
	{
		children = p_children;
		spacing = p_spacing;
	}

	public override RealSize layout(UIView p_renderer, SizeRequest p_request) nothrow
	{
		SizeRequest request = p_request.constrained(absoluteWidth, absoluteHeight);

		//TODO: respect intrinsics properly
		RealSize size;
		ivec2 pen = ivec2(0,0);
		foreach(child; children)
		{
			RealSize childSize = child.layout(p_renderer, request);
			child.position.x = -childSize.width/2;
			child.position.y = pen.y;

			size.width = childSize.width > size.width? childSize.width: size.width;
			size.height = pen.y + childSize.height;

			pen.y += childSize.height + spacing;
		}

		foreach(child; children)
		{
			child.position.x += size.width/2;
		}

		return size;
	}
}