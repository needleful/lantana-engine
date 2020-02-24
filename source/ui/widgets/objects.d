// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module ui.widgets.objects;

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

public class PatchRect : RectWidget
{
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
		super.initialize(p_renderer, p_view);
		mesh = view.addPatchRect(sprite, pad);
	}

	public override RealSize layout(SizeRequest p_request) 
	{
		if(!visible || p_request == SizeRequest.hide)
		{
			view.setPatchRectSize(mesh, RealSize(0), Pad(0));
			return RealSize(0);
		}
		// At least as large as the pad and bound to the absolute bounds
		SizeRequest rq = p_request
			.constrained(absoluteWidth, absoluteHeight)
			.constrained(
				Bounds(pad.left + pad.right, double.infinity),
				Bounds(pad.top + pad.bottom, double.infinity));

		size = RealSize(cast(int) rq.width.min, cast(int) rq.height.min);
		view.setPatchRectSize(mesh, size, pad);

		return size;
	}

	public override void prepareRender(ivec2 p_pen) 
	{
		view.translateMesh(mesh, ivec2(p_pen));
	}

	public override void setSprite(SpriteId p_sprite) 
	{
		view.setPatchRectUV(mesh, p_sprite, pad);
	}

	public override void setPosition(ivec2 p_position)
	{
		view.setPatchRectSize(mesh, size, pad);
		view.translateMesh(mesh, ivec2(p_position));
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
		super.initialize(p_renderer, p_view);
		vertices = p_view.addSpriteQuad(spriteId);
	}

	public override RealSize layout(SizeRequest p_request) 
	{
		if(!visible || p_request == SizeRequest.hide)
		{
			view.setQuadSize(vertices, RealSize(0));
			return RealSize(0);
		}
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

		view.setQuadSize(vertices, resultSize);
		return resultSize;
	}

	public override void prepareRender(ivec2 p_pen) 
	{
		ivec2 p = ivec2(p_pen.x, p_pen.y);
		view.translateMesh(vertices, p);
	}

	public override void setSprite(SpriteId p_sprite) 
	{
		view.setSprite(vertices, p_sprite);
	}

	public override void setPosition(ivec2 p_position)
	{
		view.setQuadSize(vertices, resultSize);
		view.translateMesh(vertices, ivec2(p_position));
	}
}

// TODO: implement word wrap
public class TextBox: Widget
{
	FontId font;
	string text;
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
		super.initialize(p_renderer, p_view);
		mesh = p_view.addTextMesh(font, text, allocCapacity);
	}

	public override RealSize layout(SizeRequest p_request) 
	{
		if(!visible || p_request == SizeRequest.hide)
		{
			view.setTextVisiblePercent(mesh, 0f);
			return RealSize(0);
		}
		view.setTextVisiblePercent(mesh, 1);
		// TODO: layout text to fit bounds
		return view.textBoundingBox(mesh);
	}

	public override void prepareRender(ivec2 p_pen) 
	{
		view.translateTextMesh(mesh, p_pen);
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

	public FontId getFont()
	{
		return font;
	}
}

public class Button: MultiContainer, Interactible
{
	private InteractibleId id;
	public Interactible.Callback onPressed;
	private bool pressed;

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
		super.initialize(p_renderer, p_view);
		id = p_view.addInteractible(this);
	}

	public override RealSize layout(SizeRequest p_request) 
	{
		if(!visible || p_request == SizeRequest.hide)
		{
			return layoutEmpty();
		}
		RealSize childSize = children[1].layout(p_request);
		children[0].layout(SizeRequest(childSize));
		view.setInteractSize(id, childSize);
		return childSize;
	}

	public override void prepareRender(ivec2 p_pen) 
	{
		view.setInteractPosition(id, p_pen);
		super.prepareRender(p_pen);
	}

	public override short priority()
	{
		return 1;
	}
	/// Interactible methods
	public override void focus() {}

	public override void unfocus()
	{
		if(pressed) onPressed(this);
		pressed = false;
		(cast(RectWidget)children[0]).setSprite(view.renderer.style.button.normal);
	}

	public override void drag(ivec2 _) {}

	public override void interact()
	{
		pressed = true;
		(cast(RectWidget)children[0]).setSprite(view.renderer.style.button.pressed);
	}

	public Widget getChild()
	{
		return (cast(Container)children[1]).getChildren()[0];
	}
}