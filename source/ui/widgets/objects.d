// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module ui.widgets.objects;

import std.math;
debug import std.stdio;

import gl3n.linalg: vec2, vec3;

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
	float scale;

	// Instead of rendering a sprite, render a colored rectangle
	public this(UIRenderer p_renderer, AlphaColor p_color, RealSize p_size) 
	{
		spriteId = p_renderer.addSinglePixel(p_color);
		textureSize = p_size;
		scale = 1;
	}

	/// Currently no way for the UIRenderer to check if an image is loaded,
	/// so only use this if the image is going to be shown once on screen
	public this(UIRenderer p_renderer, string filename, float p_scale = 1) 
	{
		spriteId = p_renderer.loadSprite(filename);
		assert(spriteId != 0);
		scale = p_scale;
	}

	public this(SpriteId p_spriteId, float p_scale = 1) 
	{
		spriteId = p_spriteId;
		scale = p_scale;
	}

	public override void initialize(UIRenderer p_renderer, UIView p_view)
	{
		super.initialize(p_renderer, p_view);
		vertices = p_view.addSpriteQuad(spriteId);
		if(textureSize.width == 0 && textureSize.height == 0)
		{
			textureSize = p_renderer.getSpriteSize(spriteId);
		}
	}

	public override RealSize layout(SizeRequest p_request) 
	{
		if(!visible || p_request == SizeRequest.hide)
		{
			view.setQuadSize(vertices, RealSize(0));
			return RealSize(0);
		}
		SizeRequest request = p_request.constrained(absoluteWidth, absoluteHeight);
		RealSize size = textureSize*scale;

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

public final class Spacer : Widget
{
	RealSize size;

	public this(RealSize p_size)
	{
		size = p_size;
	}

	public override RealSize layout(SizeRequest p_request)
	{
		return size.constrained(p_request);
	}

	public override void prepareRender(ivec2 p_pen) 
	{
		return;
	}
}

public class TextBox: Widget
{
	FontId font;
	string text;
	uint allocCapacity;
	TextId mesh;
	vec3 color;

	public this(FontId p_font, string p_text, vec3 p_color = vec3(-1), bool p_dynamic = false)
	{
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
		color = p_color;
	}

	public this(string p_text, vec3 p_color = vec3(-1), bool p_dynamic = false)
	{
		if(p_dynamic)
		{
			allocCapacity = cast(uint)(p_text.length*1.5);
		}
		else
		{
			allocCapacity = cast(uint)p_text.length;
		}
		font = FontId.invalid;
		text = p_text;
		color = p_color;
	}

	public this(FontId p_font, string p_text, uint allocLen, vec3 p_color = vec3(-1))
	{
		font = p_font;
		text = p_text;
		allocCapacity = allocLen;
		color = p_color;
	}

	public this(string p_text, uint allocLen, vec3 p_color = vec3(-1))
	{
		font = FontId.invalid;
		text = p_text;
		allocCapacity = allocLen;
		color = p_color;
	}

	public override void initialize(UIRenderer p_renderer, UIView p_view)
	{
		super.initialize(p_renderer, p_view);
		if(color == vec3(-1))
		{
			color = p_renderer.style.defaultFontColor;
		}
		if(font == FontId.invalid)
		{
			font = p_renderer.style.defaultFont;
		}
		mesh = p_view.addTextMesh(font, text, allocCapacity);
		view.setTextVisiblePercent(mesh, 1);
		view.setTextColor(mesh, color);
	}

	public override RealSize layout(SizeRequest p_request) 
	{
		if(!visible || p_request == SizeRequest.hide)
		{
			view.setTextVisiblePercent(mesh, 0f);
			return RealSize(0);
		}
		view.setTextVisiblePercent(mesh, 1);
		SizeRequest req = p_request.constrained(absoluteWidth, absoluteHeight);
		
		view.setTextMesh(mesh, font, text, req.width, true);

		return view.textBoundingBox(mesh).constrained(req);
	}

	public override void prepareRender(ivec2 p_pen) 
	{
		view.translateTextMesh(mesh, p_pen);
	}

	public void setText(string p_text) 
	{
		if(text != p_text)
		{
			text = p_text;
			view.requestUpdate();
		}
	}

	public void setColor(vec3 p_color)
	{
		if(p_color == color)
		{
			return;
		}
		color = p_color;
		view.setTextColor(mesh, color);
	}

	public FontId getFont()
	{
		return font;
	}
}