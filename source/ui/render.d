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

package enum AtlasState
{
	Text,
	Sprite,
}


/// The Grand Poobah of UI.
/// It handles all the logic for rendering UI layouts and updating them responsibly.
/// There should be exactly one UIRenderer
public final class UIRenderer
{
	/++++++++++++++++++++++++++++++++++++++
		UI Objects and State
	+++++++++++++++++++++++++++++++++++++++/

	Bitfield!AtlasState invalidated;

	package UIView[] views;

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
		FT_Error error = FT_Init_FreeType(&fontLibrary);
		if(error)
		{
			throw new Exception(format("FT failed to init library: %d", error));
		}

		windowSize = p_windowSize;
		fonts.reserve(5);

		initMaterials();

		atlasSprite = TextureAtlas!(SpriteId, AlphaColor)(RealSize(atlasSizeSprite));
		atlasText   = TextureAtlas!(GlyphId, ubyte)(RealSize(atlasSizeText));
		debug
		{
			atlasSprite.texture.blitgrid(color(255,255,0,255));
			atlasText.texture.blitgrid(255);
		}
		invalidated.setAll();

		views ~= new UIView(this, Rect(ivec2(0), p_windowSize));
	}

	public ~this()
	{
		foreach(face; fonts)
		{
			FT_Done_Face(face);
		}
		FT_Done_FreeType(fontLibrary);
	}

	public void requestUpdate() nothrow
	{
		views[0].invalidated[ViewState.Layout] = true;
	}

	public void update(float p_delta, Input* p_input)
	{
		// Widgets manage their own layouts, we just update the root layout
		views[0].updateLayout();

		foreach(view; views)
		{
			view.updateBuffers();
		}

		if(invalidated[AtlasState.Sprite])
			atlasSprite.reload();

		if(invalidated[AtlasState.Text])
			atlasText.reload();

		invalidated.clear();

		foreach(view; views)
		{
			if(view.isVisible() && view.rect.contains(p_input.mouse_position))
			{
				InteractibleId newFocus;

				if(view.getFocusedObject(p_input, newFocus))
				{
					Interactible newObject = view.interactibles[newFocus];
					if(focused && newObject != focused)
					{
						focused.unfocus();
					}

					focused = newObject;

					if(p_input.is_just_pressed(Input.Action.UI_INTERACT))
					{
						focused.interact();
					}
				}
				// Continue focusing on an object if we're dragging it
				if(focused)
				{
					if(p_input.is_pressed(Input.Action.UI_INTERACT))
					{
						ivec2 drag = ivec2(cast(int) p_input.mouse_movement.x, cast(int) p_input.mouse_movement.y);
						focused.drag(drag);
					}
					else
					{
						focused.unfocus();
						focused = null;
					}
				}
			}
		}
	}

	public void render() 
	{
		glEnable(GL_BLEND);
		glDisable(GL_DEPTH_TEST);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
		glEnable(GL_SCISSOR_TEST);
		foreach(v; views)
		{
			if(v.isVisible())
			{
				v.render(windowSize);
			}
		}
		glDisable(GL_SCISSOR_TEST);
	}

	public UIView rootView() @nogc nothrow
	{
		return views[0];
	}

	public void setRootWidget(Widget p_root)
	{
		views[0].setRootWidget(p_root);
	}

	public void setRootWidgets(Widget[] p_widgets)
	{
		views[0].setRootWidget(new HodgePodge(p_widgets));
	}

	public void setSize(RealSize p_size) nothrow
	{
		windowSize = p_size;
		views[0].setRect(Rect(views[0].position, p_size));
	}

	public RealSize getSize() nothrow
	{
		return windowSize;
	}

	/++++++++++++++++++++++++++++++++++++++
		public methods -- sprites
	+++++++++++++++++++++++++++++++++++++++/

	/// Add a sprite to be rendered
	public SpriteId addSprite(RealSize p_size, AlphaColor* p_buffer, bool p_swapRB = true) nothrow
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
	public SpriteId addSinglePixel(AlphaColor p_color) nothrow
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

	public RealSize getSpriteSize(SpriteId p_id) nothrow
	{
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
		public methods -- debug
	+++++++++++++++++++++++++++++++++++++++/

	/// Renders the sprite and text atlases.
	/// It also puts the renderer in an invalid state,
	/// so only render this once.
	debug public void debugRender()
	{
		glcheck();
		// We'll just render the atlases as quads
		views[0].uvs.length = 8;
		views[0].vertpos.length = 8;

		views[0].uvs[0..$] = [
			vec2(0,0),
			vec2(0,1),
			vec2(1,0),
			vec2(1,1),

			vec2(0,0),
			vec2(0,1),
			vec2(1,0),
			vec2(1,1)
		];

		views[0].vertpos[0..$] = [
			svec(0, 0),
			svec(0, 256),
			svec(256, 0),
			svec(256, 256),

			svec(256, 256),
			svec(256, 256+1024),
			svec(256+1024, 256),
			svec(256+1024, 256+1024)
		];

		views[0].elemText.length = 6;
		views[0].elemSprite.length = 6;

		views[0].elemText[0..$] = [
			0, 2, 1,
			1, 2, 3
		];

		views[0].elemSprite[0..$] = [
			4, 6, 5,
			5, 6, 7
		];
		views[0].invalidated.setAll();
		views[0].updateBuffers();

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