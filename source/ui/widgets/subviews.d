// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module ui.widgets.subviews;

import std.math;
debug import std.stdio;

import gl3n.linalg: vec2;

import lanlib.types;
import lanlib.util.printing;
import logic.input : Input;
import ui.interaction;
import ui.layout;
import ui.render;
import ui.view;
import ui.widgets;

/// Unlimited vertical space!
/// Other dimensions are still constrained
public final class Scrolled : Widget
{
	private final class ScrollGrab : Interactible
	{
		Scrolled parent;
		short m_priority;
		bool pan;

		this(Scrolled p_parent, bool p_pan, short p_priority) 
		{
			parent = p_parent;
			pan = p_pan;
			m_priority = p_priority;
		}

		public override void drag(ivec2 p_dragAmount) 
		{
			parent.scrollBy(cast(int) p_dragAmount.y, pan);
		}
		
		public override void interact() 
		{
			parent.scrollbarHandle.setSprite(parent.childView.renderer.style.button.pressed);
		}
		public override void unfocus() 
		{
			parent.scrollbarHandle.setSprite(parent.childView.renderer.style.button.normal);
		}
		public override void release()
		{
			if(pan)
				parent.scrollbarHandle.setSprite(parent.childView.renderer.style.button.normal);
			else
				parent.scrollbarHandle.setSprite(parent.childView.renderer.style.button.focused);
		}
		public override short priority() 
		{
			return m_priority;
		}
		/// Unimplemented Interactible methods
		public override void focus() 
		{
			if(!pan) parent.scrollbarHandle.setSprite(parent.childView.renderer.style.button.focused);
		}
	}

	private UIView childView;
	private Widget child;

	private Widget scrollbar;
	private RectWidget scrollbarHandle;

	private InteractibleId idHandle, idPan;
	private ivec2 drawPos;
	private int scrollSpan;
	private double scrollPercent = 0;
	private RealSize childSize, widgetSize;

	public this(Widget p_child, float p_scroll = 1) 
	{
		child = p_child;
		scrollPercent = p_scroll;
	}

	public override void initialize(UIRenderer p_ui, UIView p_view) 
	{
		super.initialize(p_ui, p_view);

		childView = p_view.addView(Rect.init);
		childView.setRootWidget(child);

		scrollbar = p_ui.style.scrollbar.trough.mesh.create(p_ui);
		scrollbarHandle = p_ui.style.button.mesh.create(p_ui);

		scrollbar.initialize(p_ui, p_view);
		scrollbarHandle.initialize(p_ui, p_view);

		idHandle = p_view.addInteractible(new ScrollGrab(this, false, 4));
		idPan = p_view.addInteractible(new ScrollGrab(this, true, 3));

		scrollTo(scrollPercent);
	}

	public override RealSize layout(SizeRequest p_request) 
	{
		if(!visible || p_request == SizeRequest.hide)
		{
			scrollbar.layout(SizeRequest.hide);
			scrollbarHandle.layout(SizeRequest.hide);
			childView.setVisible(false);
			view.setInteractSize(idHandle, RealSize(0));
			view.setInteractSize(idPan, RealSize(0));
			return RealSize(0);
		}
		else
		{
			childView.setVisible(true);
		}

		int scrollbarWidth = view.renderer.style.scrollbar.width;

		SizeRequest childReq = SizeRequest(
			Bounds(p_request.width.min - scrollbarWidth, p_request.width.max - scrollbarWidth), 
			Bounds.none)
		.constrained(absoluteWidth, absoluteHeight);

		widgetSize = childView.updateLayout(childReq);
		childSize = widgetSize.constrained(SizeRequest(childReq.width, p_request.height));

		double scrollRatio = childSize.height / (cast(double) widgetSize.height);

		if(scrollRatio > 1)
			scrollRatio = 1;
		else if(scrollRatio < 0)
			scrollRatio = 0;

		RealSize barsize = scrollbar.layout(SizeRequest(RealSize(scrollbarWidth, childSize.height)));
		RealSize handleSize = scrollbarHandle.layout(
			SizeRequest(
				Bounds(barsize.width), 
				Bounds(cast(int)(barsize.height*scrollRatio))
			).constrained(Bounds.none, Bounds(barsize.width))
		);

		// How far, in pixels, the user can scroll
		scrollSpan = barsize.height - handleSize.height;
		if(scrollSpan < 0) scrollSpan = 0;

		// Readjusting scroll to match old position as best as possible
		childView.translation = ivec2(0, cast(int)(-scrollPercent* (widgetSize.height - childSize.height)));

		scrollbar.position = ivec2(childSize.width, 0);

		view.setInteractSize(idHandle, barsize);
		view.setInteractSize(idPan, childSize);

		return RealSize(childSize.width + scrollbarWidth, childSize.height);
	}

	public override void prepareRender(ivec2 p_pen) 
	{
		drawPos = scrollbar.position + p_pen;
		scrollbarHandle.position = drawPos + ivec2(0, cast(int)(scrollSpan*scrollPercent));

		childView.setRect(Rect(p_pen, childSize));
		scrollbar.prepareRender(drawPos);
		scrollbarHandle.prepareRender(scrollbarHandle.position);

		view.setInteractPosition(idHandle, scrollbar.position + p_pen);
		view.setInteractPosition(idPan, p_pen);
	}

	public void scrollBy(double p_pixels, bool pan) 
	{
		double newLoc = scrollPercent;
		if(pan)
		{
			int dist = widgetSize.height - childSize.height;
			if(dist > 0)
			{
				newLoc -= p_pixels/dist;
			}
		}
		else if(scrollSpan > 0)
		{
			newLoc += p_pixels/(scrollSpan);
		}
		
		if(newLoc > 1)
			newLoc = 1;
		else if(newLoc < 0)
			newLoc = 0;

		if(newLoc == scrollPercent)
			return;

		scrollTo(newLoc);
	}

	public void scrollTo(double p_position) 
	{
		scrollPercent = p_position;

		childView.translation.y = cast(int) (-scrollPercent*(widgetSize.height-childSize.height));
		scrollbarHandle.position.y = drawPos.y + cast(int)(scrollPercent*scrollSpan);
		scrollbarHandle.setPosition(scrollbarHandle.position);
	}
}

public class Panned : Widget, Interactible
{
	UIView childView;
	MultiContainer widget;

	RealSize viewSize;
	InteractibleId pan;

	public this(Widget[] widgets)
	{
		widget = new HodgePodge(widgets);
	}

	public override void initialize(UIRenderer p_renderer, UIView p_view)
	{
		super.initialize(p_renderer, p_view);
		childView = p_view.addView(Rect.init);
		childView.setRootWidget(widget);

		pan = view.addInteractible(this);
	}

	public override RealSize layout(SizeRequest p_request)
	{
		if(!visible || p_request == SizeRequest.hide)
		{
			childView.setVisible(false);
			return RealSize(0);
		}
		childView.setVisible(true);
		viewSize = childView.updateLayout(p_request.constrained(absoluteWidth, absoluteWidth));

		return viewSize;
	}

	public override void prepareRender(ivec2 p_pen)
	{
		view.setInteractSize(pan, viewSize);
		view.setInteractPosition(pan, p_pen);
		childView.setRect(Rect(p_pen, viewSize));
	}

	public MultiContainer container()
	{
		return widget;
	}

	public override short priority()
	{
		return 0;
	}

	public override void drag(ivec2 p_dragAmount) 
	{
		childView.translation += p_dragAmount;
	}
	
	public override void interact() {}
	public override void unfocus() {}
	public override void focus() {}
	public override void release() {}
}
public final class Modal : Widget
{
	private UIView[] views;
	private Widget[] widgets;

	private uint currentMode;

	public this(Widget[] p_widgets) 
	{
		widgets = p_widgets;
		views.reserve(widgets.length);
	}

	public override void initialize(UIRenderer p_renderer, UIView p_view) 
	{
		super.initialize(p_renderer, p_view);

		foreach(w; widgets)
		{
			UIView v = p_view.addView(Rect(ivec2(0,0), p_renderer.getSize()));

			v.setVisible(false);
			v.setRootWidget(w);

			views ~= v;
		}

		views[currentMode].setVisible(true);
	}

	public void addMode(Widget w)
	{
		UIView v = view.addView(Rect(ivec2(0,0), view.renderer.getSize()));
		v.setVisible(false);
		v.setRootWidget(w);
		widgets ~= w;
		views ~= v;
	}

	public override RealSize layout(SizeRequest p_request) 
	{
		if(!visible || p_request == SizeRequest.hide)
		{
			foreach(v; views)
			{
				v.setVisible(false);
			}
			return RealSize(0);
		}
		else
		{
			views[currentMode].setVisible(true);
		}

		foreach(v; views)
		{
			v.setRect(Rect(ivec2(0,0), view.renderer.getSize()));
		}

		return widgets[currentMode].layout(p_request);
	}

	public override void prepareRender(ivec2 p_pen) 
	{
		Widget wi = widgets[currentMode];

		wi.prepareRender(p_pen + wi.position);
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
		views[p_mode].requestUpdate();
		
		currentMode = p_mode;
	}
}