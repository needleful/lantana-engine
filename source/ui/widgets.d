// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module ui.widgets;

import std.math;
debug import std.stdio;

import gl3n.linalg: vec2;

import lanlib.types;
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
	public this(UIRenderer p_renderer, AlphaColor p_color, RealSize p_size)
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

	public this(UIRenderer p_renderer, SpriteId p_spriteId)
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
	public void focus()
	{
		// TODO: implement
		return;
	}

	public void unfocus()
	{
		// TODO: implement
	}

	public void interact()
	{
		onPressed(this);
	}
}

/// Unlimited vertical space!
/// Other dimensions are still constrained
public class Scrolled : LeafWidget
{
	private UIView childView;
	private Widget child;
	private RealSize childSize;

	public this(Widget p_child) nothrow
	{
		child = p_child;
	}

	public override void initialize(UIRenderer p_renderer, UIView p_view) nothrow
	{
		childView = p_renderer.addView(Rect.init);
		childView.setRootWidget(child);
	}

	public override RealSize layout(UIView p_view, SizeRequest p_request) nothrow
	{
		SizeRequest rq = SizeRequest(p_request.width. Bounds.none);

		childSize = childView.updateLayout(rq).constrained(p_request);
		
		return childSize;
	}

	public override void prepareRender(UIView p_view, ivec2 p_pen) nothrow
	{
		childView.setRect(Rect(p_pen, childSize));
	}
}