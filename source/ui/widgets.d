// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module ui.widgets;

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

public abstract class LeafWidget : Widget
{
	public override Widget[] getChildren() nothrow
	{
		return [];
	}
}

public class ImageBox : LeafWidget
{
	RealSize textureSize;
	SpriteId spriteId;
	// indeces into the UIRenderer vertex buffer
	ushort[] vertices;

	// Instead of rendering a sprite, render a colored rectangle
	public this(UIRenderer p_renderer, AlphaColor p_color, RealSize p_size) nothrow
	{
		spriteId = p_renderer.addSinglePixel(p_color);
		textureSize = p_size;
	}

	/// Currently no way for the UIRenderer to check if an image is loaded,
	/// so only use this if the image is going to be shown once on screen
	public this(UIRenderer p_renderer, string filename) 
	{
		spriteId = p_renderer.loadSprite(filename);
		assert(spriteId != 0);
		textureSize = p_renderer.getSpriteSize(spriteId);
	}

	public this(UIRenderer p_renderer, SpriteId p_spriteId) nothrow
	{
		spriteId = p_spriteId;
		textureSize = p_renderer.getSpriteSize(spriteId);
	}

	public override void initialize(UIRenderer p_renderer, UIView p_view)
	{
		vertices = p_view.addSpriteQuad(spriteId);
		assert(vertices.length == 6);
	}

	public override RealSize layout(UIView p_view, SizeRequest p_request) nothrow
	{
		SizeRequest request = p_request.constrained(absoluteWidth, absoluteHeight);
		RealSize size = textureSize;

		// The goal is to keep textures as close to their original size as possible, to avoid any stretching
		// Failing that, it tries to keep the aspect ratio of the image
		// TODO: currently does not do much to save aspect ratio

		double wrMax = request.width.max / size.width;
		double wrMin = request.width.min / size.width;
		double wrIdeal = 1;

		if(wrIdeal < wrMin)
		{
			wrIdeal = wrMin;
		}
		else if(wrIdeal > wrMax)
		{
			wrIdeal = wrMax;
		}

		double hrMax = request.height.max / size.height;
		double hrMin = request.height.min / size.height;
		double hrIdeal = 1;

		if(hrIdeal < hrMin)
		{
			hrIdeal = hrMin;
		}
		else if(hrIdeal > hrMax)
		{
			hrIdeal = hrMax;
		}

		double hDiff = abs(1.0 - hrIdeal);
		double wDiff = abs(1.0 - wrIdeal);

		if(hDiff < wDiff)
		{
			// Height ratio is better at preserving size, try to match width
			if(hrIdeal < wrMin)
			{
				wrIdeal = wrMin;
			}
			else if(hrIdeal > wrMax)
			{
				wrIdeal = wrMax;
			}
			else
			{
				wrIdeal = hrIdeal;
			}
		}
		else
		{
			if(wrIdeal < hrMin)
			{
				hrIdeal = hrMin;
			}
			else if(wrIdeal > hrMax)
			{
				hrIdeal = hrMax;
			}
			else
			{
				hrIdeal = wrIdeal;
			}
		}

		RealSize result = RealSize(cast(int)(size.width * wrIdeal), cast(int)(size.height * hrIdeal));

		p_view.setQuadSize(vertices, result);
		return result;
	}

	public override void prepareRender(UIView p_view, ivec2 p_pen) nothrow
	{
		svec2 p = svec(p_pen.x, p_pen.y);
		p_view.translateQuad(vertices, p);
	}

	public void changeSprite(UIView p_view, SpriteId p_sprite) nothrow
	{
		p_view.changeSprite(vertices, p_sprite);
	}
}

// TODO: implement word wrap
public class TextBox: LeafWidget
{
	FontId font;
	string text;
	TextMeshRef* mesh;
	UIView view;
	bool textChanged;
	bool dynamicSize;

	public this(FontId p_font, string p_text, bool p_dynamicSize = false)
	{
		font = p_font;
		text = p_text;

		dynamicSize = p_dynamicSize;
	}

	public override void initialize(UIRenderer p_renderer, UIView p_view)
	{
		mesh = p_view.addTextMesh(font, text, dynamicSize);
		view = p_view;
	}

	public override RealSize layout(UIView p_renderer, SizeRequest p_request) nothrow
	{
		// TODO: layout text to fit bounds
		return mesh.boundingSize;
	}

	public override void prepareRender(UIView p_renderer, ivec2 p_pen) nothrow
	{
		p_renderer.translateTextMesh(mesh, p_pen);
	}

	public void setText(string p_text) nothrow
	{
		if(text != p_text)
		{
			view.setTextMesh(mesh, font, p_text);
		}
		text = p_text;
	}

	public void setVisiblePortion(float p_visible)  nothrow
	{
		mesh.visiblePortion = p_visible;
	}

	public float getPortionVisible()  nothrow
	{
		return mesh.visiblePortion;
	}
}

public class Button: Container, Interactible
{
	Interactible.Callback onPressed;
	InteractibleId id;
	//Interactible.State state;

	public this(UIRenderer p_renderer, Widget p_child, SpriteId p_patchRect, Interactible.Callback p_onPressed)
	{
		children.reserve(2);
		children ~= p_child;
		children ~= new ImageBox(p_renderer, p_patchRect);
		onPressed = p_onPressed;

		children[0].position = ivec2(0,0);
		children[1].position = ivec2(0,0);
	}

	public override void initialize(UIRenderer p_renderer, UIView p_view)
	{
		id = p_view.addInteractible(this);
		super.initialize(p_renderer, p_view);
	}

	public override RealSize layout(UIView p_view, SizeRequest p_request) nothrow
	{
		RealSize childSize = children[0].layout(p_view, p_request);
		children[1].layout(p_view, SizeRequest(childSize));
		p_view.setInteractSize(id, childSize);
		return childSize;
	}

	public override void prepareRender(UIView p_view, ivec2 p_pen) nothrow
	{
		p_view.setInteractPosition(id, p_pen);
		super.prepareRender(p_view, p_pen);
	}

	/// Interactible methods
	public override void focus() {}

	public override void unfocus() {}

	public override void drag(ivec2 _) {}

	public override void interact()
	{
		onPressed(this);
	}
}

/// Unlimited vertical space!
/// Other dimensions are still constrained
public class Scrolled : LeafWidget, Interactible
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

	public this(Widget p_child) nothrow
	{
		child = p_child;
	}

	public override void initialize(UIRenderer p_renderer, UIView p_view) nothrow
	{
		parentView = p_view;
		childView = p_renderer.addView(Rect.init);
		childView.setRootWidget(child);

		spriteNormal = p_renderer.addSinglePixel(color(100, 100, 200, 255));
		spriteDragging = p_renderer.addSinglePixel(color(200, 200, 255, 255));

		scrollbar = new ImageBox(p_renderer, color(0,0,0, 150), RealSize(1));
		scrollbarHandle = new ImageBox(p_renderer, spriteNormal);

		scrollbar.initialize(p_renderer, p_view);
		scrollbarHandle.initialize(p_renderer, p_view);

		id = p_view.addInteractible(this);
	}

	public override RealSize layout(UIView p_view, SizeRequest p_request) nothrow
	{
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