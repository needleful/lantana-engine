// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module ui.subviews;

import std.math;
debug import std.stdio;

import gl3n.linalg: vec2;

import lanlib.types;
import lanlib.util.printing;
import logic.input : Input;
import ui.containers : Container;
import ui.interaction;
import ui.layout;
import ui.render;
import ui.view;
import ui.widgets;

/// Unlimited vertical space!
/// Other dimensions are still constrained
public final class Scrolled : LeafWidget, Interactible
{
	private UIView parentView;
	private UIView childView;
	private Widget child;
	private RealSize childSize;

	private Widget scrollbar;
	private ImageBox scrollbarHandle;
	private SpriteId spriteNormal, spriteDragging;

	private InteractibleId id;
	private int scrollLocation = 0;
	private int scrollSpan;
	private float scrollRatio = 1;

	public this(Widget p_child, float p_scroll = 1) nothrow
	{
		child = p_child;

		// A hack to set the scroll bar's position before anything's been laid out
		scrollSpan = 100;
		scrollLocation = cast(int)(scrollSpan * p_scroll);
	}

	public override void initialize(UIRenderer p_renderer, UIView p_view) nothrow
	{
		float oldScroll = scrollSpan == 0 ? 0 : scrollLocation/cast(float)scrollSpan;
		parentView = p_view;
		childView = p_view.addView(Rect.init);
		childView.setRootWidget(child);

		spriteNormal = p_renderer.addSinglePixel(color(100, 100, 200, 255));
		spriteDragging = p_renderer.addSinglePixel(color(200, 200, 255, 255));

		scrollbar = new ImageBox(p_renderer, color(0,0,0, 150), RealSize(1));
		scrollbarHandle = new ImageBox(p_renderer, spriteNormal);

		scrollbar.initialize(p_renderer, p_view);
		scrollbarHandle.initialize(p_renderer, p_view);

		id = p_view.addInteractible(this);
		scrollTo(oldScroll);
	}

	public override RealSize layout(UIView p_view, SizeRequest p_request) nothrow
	{
		printf("Start scroll(%p) layout\n", this);
		int scrollbarWidth = 20;

		SizeRequest childReq = SizeRequest(
			Bounds(p_request.width.min - scrollbarWidth, p_request.width.max - scrollbarWidth), 
			Bounds.none)
		.constrained(absoluteWidth, absoluteHeight);

		RealSize result = childView.updateLayout(childReq);

		childSize = result.constrained(p_request);
		childSize.width -= scrollbarWidth;

		scrollRatio = childSize.height / (cast(float) result.height);

		if(scrollRatio > 1)
		{
			scrollRatio = 1;
		}
		if(scrollRatio < 0.1)
		{
			scrollRatio = 0.1;
		}

		RealSize barsize = scrollbar.layout(p_view, SizeRequest(Bounds(scrollbarWidth), Bounds(childSize.height)));
		
		RealSize handleSize = scrollbarHandle.layout(
			p_view,
			SizeRequest(
				Bounds(barsize.width), 
				Bounds(cast(int)(barsize.height*scrollRatio))
			)
		);

		float oldScroll = scrollSpan == 0 ? 0 : scrollLocation/cast(float)scrollSpan;

		// How far, in pixels, the user can scroll
		scrollSpan = barsize.height - handleSize.height;
		if(scrollSpan < 0) scrollSpan = 0;

		// Readjusting scroll to match old position as best as possible
		scrollLocation = cast(int)(scrollSpan * oldScroll);
		childView.translation = ivec2(0, cast(int)(-scrollLocation/scrollRatio));

		scrollbar.position = ivec2(childSize.width, 0);
		scrollbarHandle.position = ivec2(scrollbar.position.x, scrollLocation);

		p_view.setInteractSize(id, barsize);

		printT("End scroll % layout: % -> %\n", cast(void*) this, p_request, result);

		return RealSize(childSize.width + scrollbarWidth, childSize.height);
	}

	public override void prepareRender(UIView p_view, ivec2 p_pen) nothrow
	{
		scrollbarHandle.position = ivec2(scrollbar.position + p_pen + ivec2(0, scrollLocation));

		childView.setRect(Rect(p_pen, childSize));
		scrollbar.prepareRender(p_view, p_pen + scrollbar.position);
		scrollbarHandle.prepareRender(p_view, scrollbarHandle.position);

		p_view.setInteractPosition(id, scrollbar.position + p_pen);
	}

	public override void drag(ivec2 p_dragAmount) nothrow
	{
		scrollBy(cast(int) p_dragAmount.y);
	}
	
	public override void interact() nothrow
	{
		scrollbarHandle.changeSprite(parentView, spriteDragging);
	}
	public override void unfocus() nothrow
	{
		scrollbarHandle.changeSprite(parentView, spriteNormal);
	}

	public void scrollBy(int p_pixels) nothrow
	{
		int newLoc = scrollLocation - p_pixels;

		if(newLoc < 0 )
		{
			newLoc = 0;
		}
		else if(newLoc > scrollSpan)
		{
			newLoc = scrollSpan;
		}

		if(newLoc == scrollLocation)
		{
			return;
		}

		int pixels = scrollLocation - newLoc;

		scrollLocation = newLoc;

		childView.translation = ivec2(0, cast(int)(-scrollLocation/scrollRatio));

		ivec2 pos = ivec2(0, -pixels);
		scrollbarHandle.position += pos;
		scrollbarHandle.prepareRender(parentView, pos);
	}

	public void scrollTo(float p_position) nothrow
	{
		float pos = p_position;
		if(pos < 0)
		{
			pos = 0;
		}
		else if(pos > 1)
		{
			pos = 1;
		}

		int desiredLoc = cast(int)(scrollSpan * pos);

		scrollBy(scrollLocation - desiredLoc);
	}

	/// Unimplemented Interactible methods
	public override void focus() {}
}

public final class Modal : LeafWidget
{
	private UIView[] views;
	private Widget[] widgets;

	private uint currentMode;
	private Rect childRect;

	public this(Widget[] p_widgets) nothrow
	{
		widgets = p_widgets;
		views.reserve(widgets.length);
	}

	public override void initialize(UIRenderer p_renderer, UIView p_view) nothrow
	{
		foreach(w; widgets)
		{
			UIView v = p_view.addView(Rect(ivec2(0,0), p_renderer.getSize()));

			v.setVisible(false);
			v.setRootWidget(w);

			views ~= v;
		}

		views[currentMode].setVisible(true);
	}

	public override RealSize layout(UIView p_view, SizeRequest p_request) nothrow
	{
		foreach(view; views)
		{
			view.setRect(Rect(ivec2(0,0), p_view.renderer.getSize()));
		}

		UIView v = views[currentMode];

		return widgets[currentMode].layout(v, p_request);
	}

	public override void prepareRender(UIView p_view, ivec2 p_pen) nothrow
	{
		UIView v = views[currentMode];
		Widget wi = widgets[currentMode];

		wi.prepareRender(v, p_pen + wi.position);
	}

	public uint totalModes()
	{
		return cast(uint)views.length;
	}

	public uint getMode()
	{
		return currentMode;
	}

	public void setMode(uint p_mode)
	{
		if(p_mode == currentMode)
		{
			return;
		}
		views[currentMode].setVisible(false);

		views[p_mode].setVisible(true);
		views[p_mode].updateLayout();

		currentMode = p_mode;
	}
}