// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.ui.widgets.containers;

import std.math;
debug import std.stdio;

import gl3n.linalg: vec2;

import lantana.math.func: max;
import lantana.types;
import lantana.ui.interaction;
import lantana.ui.render;
import lantana.ui.view;
import lantana.ui.widgets;

/// Provides no layout hints.  All widgets are laid out in the same space and position
public class HodgePodge : MultiContainer
{
	public this(Widget[] p_children) 
	{
		children = p_children;
	}

	public override RealSize layout(SizeRequest p_request) 
	{
		if(!visible || p_request == SizeRequest.hide) return layoutEmpty();

		SizeRequest request = p_request.constrained(absoluteWidth, absoluteHeight);

		ivec2 top_right;

		auto childRequest = SizeRequest(Bounds(0, request.width.max), Bounds(0, request.height.max));

		foreach(child; children)
		{
			RealSize csize = child.layout(childRequest);
			top_right = ivec2(max(csize.width, top_right.x), max(csize.height, top_right.y));
		}

		return RealSize(top_right.x, top_right.y).constrained(request);
	}
}

/// Relative positioning with no size constraints on object
public class Positioned: SingularContainer
{
	vec2 anchor;
	vec2 childAnchor;

	public this(Widget p_child, vec2 p_anchor, vec2 p_childAnchor) 
	{
		child = p_child;
		anchor = p_anchor;
		childAnchor = p_childAnchor;
	}

	public override RealSize layout(SizeRequest p_request)
	{
		if(!visible || p_request == SizeRequest.hide) return layoutEmpty();

		SizeRequest childRequest = SizeRequest(absoluteWidth, absoluteHeight);
		RealSize childSize = child.layout(childRequest);

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
	UIView view;
	// Normalized coordinates, (0,0) is bottom left of the MultiContainer
	vec2 anchor;
	// Normalized coordinates of anchor for child element.  This is what's moved to the anchor
	vec2 childAnchor;

	public this(Widget p_child, vec2 p_anchor, vec2 p_childAnchor = vec2(0,0)) 
	{
		child = p_child;
		child.position = ivec2(0,0);

		anchor = p_anchor;
		childAnchor = p_childAnchor;
	}

	public override RealSize layout(SizeRequest p_request) 
	{
		if(!visible || p_request == SizeRequest.hide) return layoutEmpty();

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
			else childIntrinsic.width.max = childWidthMeetingLeft;
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
			else childIntrinsic.height.max = childHeightMeetingTop;
		}

		RealSize childSize = child.layout(childIntrinsic);

		child.position = ivec2(
			cast(int)(parentWidth*anchor.x - childSize.width*childAnchor.x),
			cast(int)(parentHeight*anchor.y - childSize.height*childAnchor.y));

		debug assert(child.position.x >= 0 && child.position.y >= 0, "Child extends beyond MultiContainer bounds.");

		// Final size of the MultiContainer
		RealSize result = RealSize(childSize.width + position.x, childSize.height + position.y);
		debug assert(!result.contains(RealSize(cast(int)parentHeight, cast(int)parentWidth)), "Child is larger than MultiContainer.");

		return result;
	}
}

public class AnchoredBox : MultiContainer
{
	vec2 bottomLeft;
	vec2 topRight;

	public this(Widget[] p_children, vec2 p_bLeft, vec2 p_tRight)
	{
		children = p_children;
		bottomLeft = p_bLeft;
		topRight = p_tRight;
	}

	public override RealSize layout(SizeRequest p_request)
	{
		if(!visible || p_request == SizeRequest.hide) return layoutEmpty();

		// AnchoredBox forces its children to occupy the full box
		SizeRequest childRequest;

		vec2 vSize = topRight - bottomLeft;
		childRequest.width = Bounds(p_request.width.max * vSize.x);
		childRequest.height = Bounds(p_request.height.max * vSize.y);

		childRequest = childRequest.constrained(absoluteWidth, absoluteHeight);

		foreach(child; children)
		{
			child.position = ivec2(cast(int)(p_request.width.max*bottomLeft.x), cast(int)(p_request.height.max*bottomLeft.y));
			child.layout(childRequest);
		}

		return RealSize(cast(int) childRequest.width.max, cast(int) childRequest.height.max);
	}
}

public class Padding : SingularContainer
{
	// Padding, in pixels
	Pad pad;
	RectWidget panel;

	public this(Widget p_child, Pad p_pad, RectWidget p_panel = null) 
	{
		child = p_child;
		pad = p_pad;
		panel = p_panel;
	}

	public override void initialize(UIRenderer p_renderer, UIView p_view)
	{
		if(panel)
		{
			panel.initialize(p_renderer, p_view);
		}
		super.initialize(p_renderer, p_view);
	}

	public override RealSize layout(SizeRequest p_request) 
	{
		if(!visible || p_request == SizeRequest.hide) 
		{
			if(panel) panel.layout(SizeRequest.hide);
			return layoutEmpty();
		}

		SizeRequest request = p_request.constrained(absoluteWidth, absoluteHeight);

		double maxWidth = request.width.max - (pad.left + pad.right);
		double minWidth = request.width.min - (pad.left + pad.right);

		double maxHeight = request.height.max - (pad.top + pad.bottom);
		double minHeight = request.height.min - (pad.top + pad.bottom);

		// Constrain child to the full box (or infinity)
		SizeRequest childIntrinsic = SizeRequest(Bounds(minWidth, maxWidth), Bounds(minHeight, maxHeight));

		RealSize csize = child.layout(childIntrinsic);
		child.position = ivec2(pad.left, pad.bottom);

		RealSize res = RealSize(csize.width + pad.left + pad.right, csize.height + pad.top + pad.bottom);
		if(panel) panel.layout(SizeRequest(res));
		return res.constrained(SizeRequest(absoluteWidth, absoluteHeight));
	}

	public override void prepareRender(ivec2 p_pen)
	{
		if(panel) panel.prepareRender(p_pen);
		super.prepareRender(p_pen);
	}
}

public class HBox: MultiContainer
{
	// Space between children
	int spacing;
	Alignment alignment;

	this(Widget[] p_children, int p_spacing = 0, Alignment p_align = Alignment.CENTER)
	{
		children = p_children;
		spacing = p_spacing;
		alignment = p_align;
	}

	public override RealSize layout(SizeRequest p_request) 
	{
		if(!visible || p_request == SizeRequest.hide) return layoutEmpty();

		SizeRequest request = p_request.constrained(absoluteWidth, absoluteHeight);

		request.width.min = 0;

		//TODO: respect intrinsics properly
		RealSize size;
		ivec2 pen = ivec2(0,0);
		foreach(child; children)
		{
			RealSize childSize = child.layout(request);
			child.position.x = pen.x;

			if(alignment == Alignment.CENTER)
			{
				child.position.y = -childSize.height/2;
			}
			else if(alignment == Alignment.BOTTOM)
			{
				child.position.y = 0;
			}
			else if(alignment == Alignment.TOP)
			{
				child.position.y = -childSize.height;
			}

			size.width = pen.x + childSize.width;
			size.height = childSize.height > size.height? childSize.height: size.height;

			pen.x += childSize.width + spacing;
			request.width.max -= (childSize.width + spacing);
		}

		if(alignment == Alignment.CENTER) foreach(child; children)
		{
			child.position.y += size.height/2;
		}
		else if(alignment == Alignment.TOP) foreach(child; children)
		{
			child.position.y += size.height;
		}

		return size;
	}
}

/// Goes from bottom to top
class VBox: MultiContainer
{
	// Force expand, center children, and other settings
	HFlags flags;
	// Space between children
	int spacing;

	// Put children from top to bottom
	// TODO: make adding new children put them on the bottom, too
	this(Widget[] p_children, int p_spacing = 0, HFlags p_flags = HFlags.init)
	{
		children = p_children;
		spacing = p_spacing;
		flags = p_flags;
	}

	public override RealSize layout(SizeRequest p_request) 
	{
		if(!visible || p_request == SizeRequest.hide) return layoutEmpty();

		SizeRequest childRequest = p_request.constrained(absoluteWidth, absoluteHeight);
		
		childRequest.height.min = 0;
		if(flags[HFlag.Expand])
		{
			childRequest.width.min = childRequest.width.max;
		}
		else
		{
			childRequest.width.min = 0;
		}

		RealSize size;
		uint vertPos = 0;
		// Going through the items backwards
		for(int i = cast(int)(children.length - 1); i >= 0; i--)
		{
			Widget child = children[i];
			RealSize childSize = child.layout(childRequest);

			if(flags[HFlag.Center]) 
			{
				child.position.x = -childSize.width/2;
			}
			else
			{
				child.position.x = 0;
			}
			child.position.y = vertPos;

			size.width = childSize.width > size.width? childSize.width: size.width;
			size.height = vertPos + childSize.height;

			vertPos += childSize.height + spacing;
			childRequest.height.max -= (childSize.height + spacing);
		}

		if(size.width > p_request.width.max)
		{
			size.width = cast(int) p_request.width.max;
		}
		if(size.width < p_request.width.min)
		{
			size.width = cast(int) p_request.width.min;
		}

		if(flags[HFlag.Center]) foreach(child; children)
		{
			child.position.x += size.width/2;
		}

		return size.constrained(SizeRequest(absoluteWidth, absoluteHeight));
	}
}