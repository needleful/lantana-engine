// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module ui.widgets;

import std.math;
debug import std.stdio;

import gl3n.linalg: vec2;

import lanlib.file.uidl;
import lanlib.types;
import ui.containers : Container;
import ui.interaction;
import ui.layout;
import ui.render;

public abstract class LeafWidget : Widget
{
	public override Widget[] getChildren() nothrow
	{
		return [];
	}
}

@WidgetName("image")
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
		init(p_renderer);
	}

	/// Currently no way for the UIRenderer to check if an image is loaded,
	/// so only use this if the image is going to be shown once on screen
	public this(UIRenderer p_renderer, @Param(0) string filename)
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

	public override RealSize layout(UIRenderer p_renderer, SizeRequest p_request) nothrow
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

		p_renderer.setQuadSize(vertices, result);
		return result;
	}

	public override void prepareRender(UIRenderer p_renderer, ivec2 p_pen) nothrow
	{
		svec2 p = svec(p_pen.x, p_pen.y);
		p_renderer.translateQuad(vertices, p);
	}
}

// TODO: implement sizing
@WidgetName("text")
public class TextBox: LeafWidget
{
	FontId font;
	string text;
	TextMeshRef* mesh;
	UIRenderer renderer;
	bool textChanged;

	public this(
		UIRenderer p_renderer,
		@Param(0) FontId p_font,
		@Param(1) string p_text,
		@Ignored bool p_dynamicSize = false)
	{
		font = p_font;
		text = p_text;

		mesh = p_renderer.addTextMesh(font, text, p_dynamicSize);
		renderer = p_renderer;
	}

	public override RealSize layout(UIRenderer p_renderer, SizeRequest p_request) nothrow
	{
		// TODO: layout text to fit bounds
		return mesh.boundingSize;
	}

	public override void prepareRender(UIRenderer p_renderer, ivec2 p_pen) nothrow
	{
		p_renderer.translateTextMesh(mesh, p_pen);
	}

	public void setText(string p_text) nothrow
	{
		if(text != p_text)
		{
			renderer.setTextMesh(mesh, font, p_text);
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

@WidgetName("button")
class Button: Container, Interactible
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

		id = p_renderer.addInteractible(this);
	}

	public override RealSize layout(UIRenderer p_renderer, SizeRequest p_request) nothrow
	{
		RealSize childSize = children[0].layout(p_renderer, p_request);
		children[1].layout(p_renderer, SizeRequest(childSize));
		p_renderer.setInteractSize(id, childSize);
		return childSize;
	}

	public override void prepareRender(UIRenderer p_renderer, ivec2 p_pen) nothrow
	{
		p_renderer.setInteractPosition(id, p_pen);
		super.prepareRender(p_renderer, p_pen);
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