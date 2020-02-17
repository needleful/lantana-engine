// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module ui.render;

import std.format;
import std.math:floor;
debug import std.stdio;

import derelict.freetype;

import gl3n.linalg: vec2, vec3, Vector;
import lanlib.types;
import lanlib.util.array;
import lanlib.util.memory;
import logic.input;
import render.gl;
import render.material;
import render.textures;

import ui.containers;
import ui.interaction;
import ui.layout;
import ui.view;

struct SpriteId
{
	// Limited to 255 sprites.
	// This is meant for UI, not a 2D game.
	mixin StrictAlias!ubyte;
}

struct FontId
{
	// "Only" 255 fonts.
	mixin StrictAlias!ubyte;
}

struct InteractibleId
{
	mixin StrictAlias!ubyte;
}

struct GlyphId
{
	// Can be changed later for ligatures.
	dchar glyph;
	// The font for this glyph
	FontId font;

	public this(char p_glyph, FontId p_fontId)
	{
		glyph = p_glyph;
		font = p_fontId;
	}
}

// Text is rendered in a weird way.
// I gave up on doing it all in one draw call for various reasons.
// Instead, each text box is drawn with the same EBO and VBO, but at
// different starting points and with different lengths.
// To clarify, the EBO isn't changed
public struct TextMeshRef
{
	// The total bounding box
	RealSize boundingSize;
	// Translation of the mesh
	ivec2 translation;
	// (between 0 and 1) the proportion of characters visible.
	float visiblePortion;
	// Offset within the EBO
	ushort offset;
	// Number of quads to render
	ushort length;
	// Amount of quads allocated
	ushort capacity;
}

package enum AtlasState
{
	Text,
	Sprite,
}

/// Describes part of an array, marking the start and end
/// This is used to describe the bounds of buffers that need to be reloaded.
package struct BufferRange
{
	uint start;
	uint end;

	this(int p_start, int p_end) nothrow  @safe
	{
		start = p_start;
		end = p_end;
	}

	void clear() nothrow  @safe
	{
		start = uint.max;
		end = uint.min;
	}

	void apply(BufferRange rhs) nothrow  @safe
	{
		apply(rhs.start, rhs.end);
	}

	void apply(uint p_start, uint p_end) nothrow  @safe
	{
		start = start < p_start? start : p_start;
		end = end > p_end? end : p_end;
	}
}

/// The Grand Poobah of UI.
/// It handles all the logic for rendering UI layouts and updating them responsibly.
/// There should be exactly one UIRenderer
public class UIRenderer
{
	/++++++++++++++++++++++++++++++++++++++
		UI Objects and State
	+++++++++++++++++++++++++++++++++++++++/

	Bitfield!AtlasState invalidated;

	package UIView view;

	package RealSize windowSize;

	/// The index of the focused interactive widget
	package Interactible focused;

	/++++++++++++++++++++++++++++++++++++++
		FreeType data
	+++++++++++++++++++++++++++++++++++++++/

	// FreeType libraries are used to load fonts
	package FT_Library fontLibrary;

	// Limited to FontId.dt.max fonts (probably 255)
	package FT_Face[] fonts;

	// How many founts are loaded
	package FontId.dt fontCount;

	/++++++++++++++++++++++++++++++++++++++
		OpenGL data
	+++++++++++++++++++++++++++++++++++++++/

	struct VertAttributes
	{
		AttribId uv;
		AttribId position;
	}
	
	struct TextUniforms
	{
		/// uvec2
		UniformId cam_resolution;
		/// ivec2
		UniformId translation;
		/// uint
		UniformId in_tex;
		/// vec3
		UniformId color;
	}

	struct SpriteUniforms
	{
		/// uvec2
		UniformId cam_resolution;
		/// ivec2
		UniformId translation;
		/// uint
		UniformId in_tex;
	}

	package Material matText, matSprite;
	package VertAttributes atrText, atrSprite;
	package TextUniforms uniText;
	package SpriteUniforms uniSprite;

	enum atlasSizeText = 256;
	enum atlasSizeSprite = 512;
	package TextureAtlas!(GlyphId, ubyte) atlasText;
	package TextureAtlas!(SpriteId, AlphaColor) atlasSprite;

	package SpriteId.dt spriteCount;

	/++++++++++++++++++++++++++++++++++++++
		public methods -- basic
	+++++++++++++++++++++++++++++++++++++++/

	public this(RealSize p_windowSize)
	{
		windowSize = p_windowSize;
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
		// Reserving space for 5 fonts by default
		// can go up to FontId.dt.max (probably 255)
		fonts.reserve(5);

		FT_Error error = FT_Init_FreeType(&fontLibrary);
		if(error)
		{
			throw new Exception(format("FT failed to init library: %d", error));
		}

		initMaterials();

		atlasSprite = TextureAtlas!(SpriteId, AlphaColor)(RealSize(atlasSizeSprite));
		atlasText   = TextureAtlas!(GlyphId, ubyte)(RealSize(atlasSizeText));
		debug
		{
			atlasSprite.texture.blitgrid(color(255,255,0,255));
			atlasText.texture.blitgrid(255);
		}
		invalidated.clear();

		view = new UIView(this, Rect(ivec2(0), p_windowSize));
	}

	public ~this()
	{
		foreach(face; fonts)
		{
			FT_Done_Face(face);
		}
		FT_Done_FreeType(fontLibrary);
	}

	public void update(float p_delta, Input* p_input)
	{
		if(view.invalidated[ViewState.Layout])
		{
			view.updateLayout();
		}
		view.updateBuffers();

		if(invalidated[AtlasState.Sprite])
			atlasSprite.reload();

		if(invalidated[AtlasState.Text])
			atlasText.reload();

		invalidated.clear();

		if(view.rect.contains(p_input.mouse_position))
		{
			InteractibleId newFocus;

			if(view.getFocusedObject(p_input, newFocus))
			{
				if(focused)
				{
					focused.unfocus();
				}
				
				focused = view.interactibles[newFocus];

				if(p_input.is_just_pressed(Input.Action.UI_INTERACT))
				{
					focused.interact();
				}
			}
		}
		
	}

	public void render() 
	{
		view.render();
	}

	public void setRootWidget(Widget p_root)
	{
		view.setRootWidget(p_root);
	}

	public void setRootWidgets(Widget[] p_widgets)
	{
		view.setRootWidget(new HodgePodge(p_widgets));
	}

	public void setSize(RealSize p_size)
	{
		windowSize = p_size;
		view.rect.size = p_size;
		view.invalidated[ViewState.Layout] = true;
	}

	/++++++++++++++++++++++++++++++++++++++
		public methods -- sprites
	+++++++++++++++++++++++++++++++++++++++/

	/// Add a sprite to be rendered
	public SpriteId addSprite(RealSize p_size, AlphaColor* p_buffer, bool p_swapRB = true)
	{
		assert(spriteCount < SpriteId.dt.max, "Sprite limit exceeded.");

		spriteCount += 1;
		SpriteId id = SpriteId(spriteCount);

		auto node = atlasSprite.getAtlasSpot(id, p_size);
		if(node == null)
		{
			debug assert(0, "Failed to get atlas spot");
			else return SpriteId(0);
		}

		bool success = atlasSprite.texture.blit(node.size, node.position, p_buffer, p_swapRB);
		if(!success)
		{
			debug assert(0, "Failed to blit sprite");
			else return SpriteId(0);
		}

		invalidated[AtlasState.Sprite] = true;

		return id;
	}

	/// Add a single-pixel texture for color rectangles
	public SpriteId addSinglePixel(AlphaColor p_color)
	{
		return addSprite(RealSize(1), &p_color, false);
	}

	/// Load a sprite from a file and add it
	/// filename: the path to the image
	public SpriteId loadSprite(const string p_filename)
	{
		Bitmap!AlphaColor bitmap = Bitmap!AlphaColor(p_filename);

		auto result = addSprite(bitmap.size, bitmap.buffer);

		return result;
	}

	public RealSize getSpriteSize(SpriteId p_id)
	{
		assert(p_id in atlasSprite.map);
		return atlasSprite.map[p_id].size;
	}

	/++++++++++++++++++++++++++++++++++++++
		public methods -- fonts and text
	+++++++++++++++++++++++++++++++++++++++/

	public FontId loadFont(string p_fontfile, ubyte p_size)
	{
		FT_Face newface;
		FT_Error error = FT_New_Face(
			fontLibrary,
			p_fontfile.ptr,
			0,
			&newface);
		if ( error == FT_Err_Unknown_File_Format )
		{
			throw new Exception(format("Unsupported font format: %s", p_fontfile));
		}
		else if (error)
		{
			throw new Exception(format("Could not load font: %s.  Error code: %d", p_fontfile, error));
		}

		try
		{
			return addFont(newface, p_size);
		}
		catch(Exception e)
		{
			throw new Exception(format("Failed to load font: %s", p_fontfile), e);
		}
	}

	public FontId addFont(FT_Face p_face, ubyte p_size)
	{
		// Search if this font already exists
		auto f = fonts.indexOf(p_face);
		if(f != -1)
		{
			return FontId(cast(ubyte) f);
		}

		FT_Set_Pixel_Sizes(p_face, 0, p_size);

		assert(fontCount < FontId.dt.max, "Exceeded allowed font count");
		fonts ~= p_face;
		fontCount = cast(ubyte)(fonts.length - 1);
		return FontId(fontCount);
	}

	/++++++++++++++++++++++++++++++++++++++
		public methods -- interactive objects
	+++++++++++++++++++++++++++++++++++++++/

	public InteractibleId addInteractible(Interactible p_source) nothrow
	{
		return view.addInteractible(p_source);
	}

	public void setInteractSize(InteractibleId p_id, RealSize p_size) nothrow
	{
		return view.setInteractSize(p_id, p_size);
	}

	public void setInteractPosition(InteractibleId p_id, ivec2 p_position) nothrow
	{
		return view.setInteractPosition(p_id, p_position);
	}

	/++++++++++++++++++++++++++++++++++++++
		public methods -- debug
	+++++++++++++++++++++++++++++++++++++++/

	/// Renders the sprite and text atlases.
	/// It also puts the renderer in an invalid state,
	/// so only render this once.
	debug public void debugRender()
	{
		glcheck();
		// We'll just render the atlases as quads
		view.uvs.length = 8;
		view.vertpos.length = 8;

		view.uvs[0..$] = [
			vec2(0,0),
			vec2(0,1),
			vec2(1,0),
			vec2(1,1),

			vec2(0,0),
			vec2(0,1),
			vec2(1,0),
			vec2(1,1)
		];

		view.vertpos[0..$] = [
			svec(0, 0),
			svec(0, 256),
			svec(256, 0),
			svec(256, 256),

			svec(256, 256),
			svec(256, 256+1024),
			svec(256+1024, 256),
			svec(256+1024, 256+1024)
		];

		view.elemText.length = 6;
		view.elemSprite.length = 6;

		view.elemText[0..$] = [
			0, 2, 1,
			1, 2, 3
		];

		view.elemSprite[0..$] = [
			4, 6, 5,
			5, 6, 7
		];
		view.invalidated.setAll();
		view.updateBuffers();

		glcheck();

		render();
	}

	/++++++++++++++++++++++++++++++++++++++
		package methods
	+++++++++++++++++++++++++++++++++++++++/

	package void initMaterials()
	{
		VertAttributes _build(Material* p_mat, GLuint p_vert, GLuint p_frag)
		{
			MaterialId prog = MaterialId(glCreateProgram());
			prog.glAttachShader(p_vert);
			prog.glAttachShader(p_frag);
			prog.linkShader();

			*p_mat = Material(prog);
			assert(p_mat.canRender());

			VertAttributes atr;
			atr.uv = p_mat.getAttribId("uv");
			atr.position = p_mat.getAttribId("position");

			return atr;
		} 

		GLuint vert2d = 
			compileShader("data/shaders/screenspace2d.vert", GL_VERTEX_SHADER);
		GLuint fragText = 
			compileShader("data/shaders/text2d.frag", GL_FRAGMENT_SHADER);
		GLuint fragSprite = 
			compileShader("data/shaders/sprite2d.frag", GL_FRAGMENT_SHADER);

		atrText = _build(&matText, vert2d, fragText);
		uniText.cam_resolution = matText.getUniformId("cam_resolution");
		uniText.translation = matText.getUniformId("translation");
		uniText.in_tex = matText.getUniformId("in_tex");
		uniText.color = matText.getUniformId("color");

		atrSprite = _build(&matSprite, vert2d, fragSprite);
		uniSprite.cam_resolution = matSprite.getUniformId("cam_resolution");
		uniSprite.translation = matSprite.getUniformId("translation");
		uniSprite.in_tex = matSprite.getUniformId("in_tex");

		glDisable(GL_BLEND);
		glcheck();
	}
}