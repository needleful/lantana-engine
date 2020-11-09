// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.ui.render;

import std.format;
import std.math:floor;
debug import std.stdio;

import bindbc.sdl;
import derelict.freetype;

import gl3n.linalg: vec2, vec3, Vector;
import lantana.input;
import lantana.render.gl;
import lantana.render.material;
import lantana.render.mesh.attributes;
import lantana.render.textures;
import lantana.types;

import lantana.ui.interaction;
import lantana.ui.style;
import lantana.ui.view;
import lantana.ui.widgets;

struct SpriteId
{
	mixin StrictAlias!ushort;
}

struct FontId
{
	mixin StrictAlias!ubyte;

	enum invalid = FontId(ubyte.max);
}

struct InteractibleId
{
	mixin StrictAlias!uint;
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

	package bool initialized;

	Bitfield!AtlasState invalidated;

	package UIView[] views;

	package RealSize windowSize;
	private vec2 screenDPI;

	/// The index of the focused interactive widget
	package Interactible focused;

	/// Package style
	private UIStyle m_style;

	// Text input stuff
	package TextInput currentInput;

	/// How long to hold the arrow button to start going
	private enum TIME_HOLD_START = 0.3f;
	/// How long frequently to move arrows after holding for TIME_HOLD_START
	private enum TIME_HOLD_NEXT = 0.03f;

	private float arrowTimer;
	private bool arrowHeld = false;

	private float deleteTimer;
	private bool deleteHeld = false;

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

	private struct Vert
	{
		float uv;
		int position;
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
	package Attr!Vert atrText, atrSprite;
	package TextUniforms uniText;
	package SpriteUniforms uniSprite;

	enum atlasSizeText = 256;
	enum atlasSizeSprite = 512;
	public TextureAtlas!(GlyphId, ubyte) atlasText;
	public TextureAtlas!(SpriteId, AlphaColor) atlasSprite;

	package SpriteId.dt spriteCount;

	/++++++++++++++++++++++++++++++++++++++
		public methods -- basic
	+++++++++++++++++++++++++++++++++++++++/

	public this(RealSize p_windowSize, vec2 p_dpi)
	{
		FT_Error error = FT_Init_FreeType(&fontLibrary);
		screenDPI = p_dpi;
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
			atlasSprite.texture.blitgrid(color(255,255,0));
			atlasText.texture.blitgrid(255);
		}
		invalidated.setAll();

		views ~= new UIView(this, Rect(ivec2(0), p_windowSize));
		m_style = new UIStyle();
	}

	public ~this()
	{
		foreach(face; fonts)
		{
			FT_Done_Face(face);
		}
		FT_Done_FreeType(fontLibrary);
	}

	public vec2 getDPI()
	{
		return screenDPI;
	}

	public void updateLayout()
	{
		views[0].updateLayout();
	}

	public void initialize()
	{
		glcheck();

		foreach(view; views)
		{
			view.initBuffers();
		}
		initialized = true;
	}

	public void render(bool update = true, bool alwaysRender = true)() 
	{
		int updated = 0;
		static if(update)
		{
			foreach(view; views)
			{
				updated += view.updateBuffers();
			}
			
			if(invalidated[AtlasState.Sprite])
			{
				updated ++;
				atlasSprite.reload();
			}

			if(invalidated[AtlasState.Text])
			{
				updated ++;
				atlasText.reload();
			}
			
			invalidated.clear();
		}
		
		if(alwaysRender || updated != 0)
		{
			glDisable(GL_DEPTH_TEST);
			glDisable(GL_CULL_FACE);
			glDepthMask(GL_FALSE);
			glEnable(GL_BLEND);
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
	}

	public void updateInteraction(float delta, Input* p_input)
	{
		if(focused)
		{
			if(p_input.mouseWheel != ivec2(0))
			{
				// FIXME: BAD HACK! BAD HACK!! BAD HACK!!!
				if(focused.priority() % 3 == 0)
				{
					focused.drag(p_input.mouseWheel*30);
				}
				else
				{
					focused.drag(ivec2(p_input.mouseWheel.x, -p_input.mouseWheel.y)*15);
				}
			}
			if(p_input.isJustClicked(Input.Mouse.Left))
			{
				focused.interact();
				if(focused != currentInput)
				{
					setTextFocus(null);
				}
			}
			else if(p_input.isClicked(Input.Mouse.Left))
			{
				ivec2 drag = ivec2(cast(int) p_input.mouseMove.x, cast(int) p_input.mouseMove.y);
				focused.drag(drag);
			}
			else if(p_input.isJustReleased(Input.Mouse.Left))
			{
				focused.release();
			}
		}

		if(currentInput && currentInput.isVisible() && currentInput.view.isVisible())
		{
			bool arrowPressed = false;
			bool goleft = false;
			
			if(p_input.keyboard.isPressed(SDL_SCANCODE_LEFT))
			{
				arrowPressed = true;
				if(p_input.keyboard.isJustPressed(SDL_SCANCODE_LEFT))
				{
					currentInput.cursorLeft();
					arrowTimer = 0;
					arrowHeld = false;
				}
				goleft = true;
			}
			
			if(p_input.keyboard.isPressed(SDL_SCANCODE_RIGHT))
			{
				arrowPressed = true;
				if(p_input.keyboard.isJustPressed(SDL_SCANCODE_RIGHT))
				{
					currentInput.cursorRight();
					arrowTimer = 0;
					arrowHeld = false;
				}
				goleft = false;
			}

			if(arrowPressed)
			{
				arrowTimer += delta;
				if(arrowTimer >= TIME_HOLD_START)
				{
					arrowHeld = true;
				}
				if(arrowHeld && arrowTimer >= TIME_HOLD_NEXT)
				{
					arrowTimer = 0;
					if(goleft)
					{
						currentInput.cursorLeft();
					}
					else
					{
						currentInput.cursorRight();
					}
				}
			}

			if(p_input.keyboard.text.length != 0)
				currentInput.insert(p_input.keyboard.text);

			if(p_input.keyboard.isJustPressed(SDL_SCANCODE_RETURN))
				currentInput.insert('\n');

			if(p_input.keyboard.isPressed(SDL_SCANCODE_BACKSPACE))
			{
				if(p_input.keyboard.isJustPressed(SDL_SCANCODE_BACKSPACE))
				{
					currentInput.backSpace();
					deleteTimer = 0;
					deleteHeld = false;
				}

				deleteTimer += delta;
				if(deleteTimer >= TIME_HOLD_START)
				{
					deleteTimer = 0;
					deleteHeld = true;
				}
				if(deleteHeld && deleteTimer >= TIME_HOLD_NEXT)
				{
					deleteTimer = 0;
					currentInput.backSpace();
				}
			}
		}

		Interactible newFocus = null;
		if(!p_input.isClicked(Input.Mouse.Left))
		{
			foreach(view; views)
			{
				if(view.isVisible() && view.rect.contains(p_input.mousePos))
				{
					InteractibleId newId;

					if(view.getFocusedObject(p_input.mousePos, newId))
					{
						Interactible newObject = view.interactibles[newId];
						if(!newFocus || newObject.priority() >= newFocus.priority())
							newFocus = newObject;
					}
				}
			}
			if(newFocus !is focused)
			{
				if(focused)
					focused.unfocus();
				focused = newFocus;
				if(focused)
					focused.focus();
			}
		}
	}

	public void setTextFocus(TextInput p_input)
	{
		if(currentInput)
			currentInput.removeTextFocus();
		currentInput = p_input;
	}

	@property public UIStyle style() @nogc 
	{
		return m_style;
	}

	public UIView rootView() @nogc 
	{
		return views[0];
	}

	public void setRootWidget(Widget p_root)
	{
		views.length = 1;

		focused = null;
		views[0].setRootWidget(p_root);
	}

	public void setRootWidgets(Widget[] p_widgets)
	{
		focused = null;
		views[0].setRootWidget(new HodgePodge(p_widgets));
	}

	public Widget getRootWidget()
	{
		return views[0].getRootWidget();
	}

	public void setSize(RealSize p_size) 
	{
		windowSize = p_size;
		views[0].setRect(Rect(views[0].position, p_size));
	}

	public RealSize getSize() 
	{
		return windowSize;
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
		return atlasSprite.map[p_id].size;
	}

	/++++++++++++++++++++++++++++++++++++++
		public methods -- fonts and text
	+++++++++++++++++++++++++++++++++++++++/

	public FontId loadFont(string p_fontfile, ubyte p_size)
	{
		import std.file: exists;
		assert(exists(p_fontfile), "No such file: "~p_fontfile);
		
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
		RealSize pxSize = RealSize(cast(int)(p_size*screenDPI.x/72f), cast(int)(p_size*screenDPI.y/72f));
		auto f = fonts.indexOf(p_face);
		if(f != -1)
		{
			return FontId(cast(ubyte) f);
		}

		FT_Set_Pixel_Sizes(p_face, pxSize.width, pxSize.height);

		assert(fontCount < FontId.dt.max, "Exceeded allowed font count");
		fonts ~= p_face;
		fontCount = cast(ubyte)(fonts.length - 1);
		return FontId(fontCount);
	}

	public ushort lineHeight(FontId p_id)
	{
		FT_Face face = fonts[p_id];
		return cast(ushort)(face.size.metrics.height >> 6);
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
			ivec2(0, 0),
			ivec2(0, 256),
			ivec2(256, 0),
			ivec2(256, 256),

			ivec2(256, 256),
			ivec2(256, 256+1024),
			ivec2(256+1024, 256),
			ivec2(256+1024, 256+1024)
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
		Material _build(GLuint p_vert, GLuint p_frag)
		{
			MaterialId prog = MaterialId(glCreateProgram());
			prog.glAttachShader(p_vert);
			prog.glAttachShader(p_frag);
			prog.linkShader();

			Material mat = Material(prog);
			assert(mat.canRender());

			return mat;
		} 

		GLuint vert2d = 
			compileShader("data/shaders/screenspace2d.vert", GL_VERTEX_SHADER);
		GLuint fragText = 
			compileShader("data/shaders/text2d.frag", GL_FRAGMENT_SHADER);
		GLuint fragSprite = 
			compileShader("data/shaders/sprite2d.frag", GL_FRAGMENT_SHADER);

		matText = _build(vert2d, fragText);
		atrText = Attr!Vert(matText);

		uniText.cam_resolution = matText.getUniformId("cam_resolution");
		uniText.translation = matText.getUniformId("translation");
		uniText.in_tex = matText.getUniformId("in_tex");
		uniText.color = matText.getUniformId("color");

		matSprite = _build(vert2d, fragSprite);
		atrSprite = Attr!Vert(matSprite);

		uniSprite.cam_resolution = matSprite.getUniformId("cam_resolution");
		uniSprite.translation = matSprite.getUniformId("translation");
		uniSprite.in_tex = matSprite.getUniformId("in_tex");

		glDisable(GL_BLEND);
		glcheck();
	}
}