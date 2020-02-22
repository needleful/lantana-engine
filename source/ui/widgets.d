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
import ui.containers;
import ui.interaction;
import ui.layout;
import ui.render;
import ui.view;

public abstract class LeafWidget : Widget
{
	public override Widget[] getChildren() 
	{
		return [];
	}
}

public abstract class RectWidget : LeafWidget
{
	public void setSprite(UIView p_view, SpriteId p_sprite);

	public void setPosition(UIView p_view, ivec2 p_position);
}

public class PatchRect : RectWidget
{
	Widget child;
	SpriteId sprite;
	MeshRef mesh;
	RealSize size;
	Pad pad;

	public this(SpriteId p_sprite, Pad p_pad) 
	{
		sprite = p_sprite;
		pad = p_pad;
	}

	public override void initialize(UIRenderer p_renderer, UIView p_view)
	{
		mesh = p_view.addPatchRect(sprite, pad);
	}

	public override RealSize layout(UIView p_view, SizeRequest p_request) 
	{
		// At least as large as the pad and bound to the absolute bounds
		SizeRequest rq = p_request
			.constrained(absoluteWidth, absoluteHeight)
			.constrained(
				Bounds(pad.left + pad.right, double.infinity),
				Bounds(pad.top + pad.bottom, double.infinity));

		size = RealSize(cast(int) rq.width.min, cast(int) rq.height.min);
		p_view.setPatchRectSize(mesh, size, pad);

		return size;
	}

	public override void prepareRender(UIView p_view, ivec2 p_pen) 
	{
		p_view.translateMesh(mesh, svec(p_pen));
	}

	public override void setSprite(UIView p_view, SpriteId p_sprite) 
	{
		p_view.setPatchRectUV(mesh, p_sprite, pad);
	}

	public override void setPosition(UIView p_view, ivec2 p_position)
	{
		p_view.setPatchRectSize(mesh, size, pad);
		p_view.translateMesh(mesh, svec(p_position));
	}
}

public class ImageBox : RectWidget
{
	RealSize textureSize, resultSize;
	SpriteId spriteId;
	// indeces into the UIRenderer vertex buffer
	MeshRef vertices;

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
	}

	public override RealSize layout(UIView p_view, SizeRequest p_request) 
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

		resultSize = RealSize(cast(int)(size.width * wrIdeal), cast(int)(size.height * hrIdeal));

		p_view.setQuadSize(vertices, resultSize);
		return resultSize;
	}

	public override void prepareRender(UIView p_view, ivec2 p_pen) 
	{
		svec2 p = svec(p_pen.x, p_pen.y);
		p_view.translateMesh(vertices, p);
	}

	public override void setSprite(UIView p_view, SpriteId p_sprite) 
	{
		p_view.setSprite(vertices, p_sprite);
	}

	public override void setPosition(UIView p_view, ivec2 p_position)
	{
		p_view.setQuadSize(vertices, resultSize);
		p_view.translateMesh(vertices, svec(p_position));
	}
}

// TODO: implement word wrap
public class TextBox: LeafWidget
{
	FontId font;
	string text;
	UIView view;
	uint allocCapacity;
	TextId mesh;
	bool dynamic;
	bool textChanged;

	public this(FontId p_font, string p_text, bool p_dynamic = false)
	{
		dynamic = p_dynamic;
		if(p_dynamic)
		{
			allocCapacity = cast(uint)(p_text.length*1.5);
		}
		else
		{
			allocCapacity = cast(uint)p_text.length;
		}
		font = p_font;
		text = p_text;
	}

	public this(FontId p_font, string p_text, uint allocLen)
	{
		dynamic = true;
		font = p_font;
		text = p_text;
		allocCapacity = allocLen;
	}

	public override void initialize(UIRenderer p_renderer, UIView p_view)
	{
		mesh = p_view.addTextMesh(font, text, allocCapacity);
		view = p_view;
	}

	public override RealSize layout(UIView p_view, SizeRequest p_request) 
	{
		// TODO: layout text to fit bounds
		return p_view.textBoundingBox(mesh);
	}

	public override void prepareRender(UIView p_view, ivec2 p_pen) 
	{
		p_view.translateTextMesh(mesh, p_pen);
	}

	public void setText(string p_text) 
	{
		assert(dynamic, "This text is not dynamically resizable");
		if(text != p_text)
		{
			view.setTextMesh(mesh, font, p_text);
		}
		text = p_text;
	}

	//public void setVisiblePortion(float p_visible)  
	//{
	//	mesh.visiblePortion = p_visible;
	//}

	//public float getPortionVisible()  
	//{
	//	return mesh.visiblePortion;
	//}
}

public class Button: Container, Interactible
{
	Interactible.Callback onPressed;
	InteractibleId id;
	UIView view;

	public this(UIRenderer p_renderer, Widget p_child, Interactible.Callback p_onPressed)
	{
		children.reserve(2);
		children ~= p_renderer.style.button.mesh.create(p_renderer);
		children ~= new Padding(p_child, p_renderer.style.button.pad);
		onPressed = p_onPressed;

		children[0].position = ivec2(0,0);
		children[1].position = ivec2(0,0);
	}

	public override void initialize(UIRenderer p_renderer, UIView p_view)
	{
		view = p_view;
		id = p_view.addInteractible(this);
		super.initialize(p_renderer, p_view);
	}

	public override RealSize layout(UIView p_view, SizeRequest p_request) 
	{
		RealSize childSize = children[1].layout(p_view, p_request);
		children[0].layout(p_view, SizeRequest(childSize));
		p_view.setInteractSize(id, childSize);
		return childSize;
	}

	public override void prepareRender(UIView p_view, ivec2 p_pen) 
	{
		p_view.setInteractPosition(id, p_pen);
		super.prepareRender(p_view, p_pen);
	}

	public override short priority()
	{
		return 1;
	}
	/// Interactible methods
	public override void focus() {}

	public override void unfocus()
	{
		(cast(RectWidget)children[0]).setSprite(view, view.renderer.style.button.normal);
	}

	public override void drag(ivec2 _) {}

	public override void interact()
	{
		(cast(RectWidget)children[0]).setSprite(view, view.renderer.style.button.pressed);
		onPressed(this);
	}
}