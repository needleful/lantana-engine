// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module ui.render;

import std.format;
import std.math:floor;
debug import std.stdio;

import bindbc.sdl;
import derelict.freetype;

import gl3n.linalg: vec2, vec3, Vector;
import lanlib.types;
import lanlib.util.array;
import lanlib.util.memory;
import logic.input;
import render.gl;
import render.material;
import render.mesh.attributes;
import render.textures;

import ui.interaction;
import ui.layout;
import ui.style;
import ui.view;
import ui.widgets;

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

package enum RenderState
{
	TextAtlas,
	SpriteAtlas,
	FrameBuffer,
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

	Bitfield!RenderState invalidated;

	package UIView[] views;

	package RealSize windowSize;

	/// The index of the focused interactive widget
	package Interactible focused;

	/// Package style
	private UIStyle m_style;

	// Text input stuff
	package TextInput currentInput;

	/// How long to hold the arrow button to start going
	private enum TIME_HOLD_START = 0.3f;
	/// How long frequently to move arrows after holding for TIME_HOLD_START
	private enum TIME_HOLD_NEXT = 0.05f;

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
		UI Framebuffer OpenGL data
	+++++++++++++++++++++++++++++++++++++++/

	// UI Frame buffer
	private GLuint uiRenderBuffer, uiRenderTexture;
	private Attr!Vert atrRenderTarget;
	private Material uiRenderMaterial;
	private UniformId uiRenderTextureUniform;

	// The quad for rendering
	private static immutable(ubyte[6]) uiRenderElems = [
		0, 1, 2
	];
	private static immutable(vec2[4]) uiRenderVertices = [
		vec2(-1,-2),
		vec2( 3, 0),
		vec2(-1, 2)
	];
	private static immutable(vec2[4]) uiRenderUVs = [
		vec2(0, -0.5),
		vec2(2, 0.5),
		vec2(0, 1.5)
	];

	/// 0: elements
	/// 1: vertices
	/// 2: UVs
	private GLuint[3] uiRenderVBO;
	private GLuint uiRenderVAO;


	/++++++++++++++++++++++++++++++++++++++
		Other OpenGL data
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
		initFramebuffer();

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

		glDeleteFramebuffers(1, &uiRenderBuffer);
		glDeleteBuffers(uiRenderVBO.length, uiRenderVBO.ptr);
		glDeleteVertexArrays(1, &uiRenderVAO);
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

	public void render() 
	{
		int buffersChanged = 0;
		foreach(view; views)
		{
			buffersChanged += view.updateBuffers();
		}
		if(buffersChanged > 0)
		{
			invalidated[RenderState.FrameBuffer] = true;
		}

		if(invalidated[RenderState.SpriteAtlas])
		{
			atlasSprite.reload();
			invalidated[RenderState.FrameBuffer] = true;
		}

		if(invalidated[RenderState.TextAtlas])
		{
			atlasText.reload();
			invalidated[RenderState.FrameBuffer] = true;
		}

		glEnable(GL_BLEND);
		glDisable(GL_DEPTH_TEST);
		glDisable(GL_CULL_FACE);
		if(invalidated[RenderState.FrameBuffer])
		{
			glBindFramebuffer(GL_FRAMEBUFFER, uiRenderBuffer);
			glClear(GL_COLOR_BUFFER_BIT);
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

			glcheck();
			glBindFramebuffer(GL_FRAMEBUFFER, 0);
		}

		glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
		uiRenderMaterial.enable();

		glBindVertexArray(uiRenderVAO);
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, uiRenderTexture);
		uiRenderMaterial.setUniform(uiRenderTextureUniform, 0);

		glDrawElements(
			GL_TRIANGLES,
			cast(int) uiRenderElems.length,
			GL_UNSIGNED_BYTE,
			cast(void*) 0);

		glcheck();
		glEnable(GL_CULL_FACE);

		invalidated.clear();
	}

	public void updateInteraction(float delta, Input* p_input)
	{
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
						{
							newFocus = newObject;
						}
					}
				}
			}
			if(newFocus !is focused)
			{
				if(focused) focused.unfocus();
				focused = newFocus;
				if(focused) focused.focus();
			}
		}

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
	}

	public void setTextFocus(TextInput p_input)
	{
		if(currentInput)
		{
			currentInput.removeTextFocus();
		}
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
		focused = null;
		views[0].setRootWidget(p_root);
	}

	public void setRootWidgets(Widget[] p_widgets)
	{
		focused = null;
		views[0].setRootWidget(new HodgePodge(p_widgets));
	}

	public void setSize(RealSize p_size) 
	{
		windowSize = p_size;
		views[0].setRect(Rect(views[0].position, p_size));
		updateRenderTarget();
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

		invalidated[RenderState.SpriteAtlas] = true;

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

	public ushort lineHeight(FontId p_id)
	{
		FT_Face face = fonts[p_id];
		return cast(ushort)(face.size.metrics.height >> 6);
	}

	/++++++++++++++++++++++++++++++++++++++
		private and package methods
	+++++++++++++++++++++++++++++++++++++++/
	private void initFramebuffer()
	{
		initRenderTarget();
		glcheck();

		// Create VBO
		glGenBuffers(uiRenderVBO.length, uiRenderVBO.ptr);
		glGenVertexArrays(1, &uiRenderVAO);
		glBindVertexArray(uiRenderVAO);

		atrRenderTarget.enable();

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, uiRenderVBO[0]);

		glBindBuffer(GL_ARRAY_BUFFER, uiRenderVBO[1]);
		glVertexAttribPointer(
			atrRenderTarget.position,
			2, GL_FLOAT,
			GL_FALSE,
			0,
			cast(void*) 0);

		glBindBuffer(GL_ARRAY_BUFFER, uiRenderVBO[2]);
		glVertexAttribPointer(
			atrRenderTarget.uv,
			2, GL_FLOAT,
			GL_FALSE,
			0,
			cast(void*) 0);

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, uiRenderVBO[0]);
		glBufferData(
			GL_ELEMENT_ARRAY_BUFFER,
			uiRenderElems.length*ubyte.sizeof,
			uiRenderElems.ptr,
			GL_STATIC_DRAW);

		glBindBuffer(GL_ARRAY_BUFFER, uiRenderVBO[1]);
		glBufferData(
			GL_ARRAY_BUFFER,
			uiRenderVertices.length*vec2.sizeof,
			uiRenderVertices.ptr,
			GL_STATIC_DRAW);

		glBindBuffer(GL_ARRAY_BUFFER, uiRenderVBO[2]);
		glBufferData(
			GL_ARRAY_BUFFER,
			uiRenderUVs.length*vec2.sizeof,
			uiRenderUVs.ptr,
			GL_STATIC_DRAW);

		glBindVertexArray(0);

		atrRenderTarget.disable();

		glcheck();
	}

	private void initRenderTarget()
	{
		glGenFramebuffers(1, &uiRenderBuffer);
		glBindFramebuffer(GL_FRAMEBUFFER, uiRenderBuffer);

		glGenTextures(1, &uiRenderTexture);
		glBindTexture(GL_TEXTURE_2D, uiRenderTexture);

		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);

		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, windowSize.width, windowSize.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, null);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, uiRenderTexture, 0);
		glDrawBuffer(GL_COLOR_ATTACHMENT0);

		assert(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE);

		glBindFramebuffer(GL_FRAMEBUFFER, 0);
		invalidated[RenderState.FrameBuffer] = true;
	}

	private void updateRenderTarget()
	{
		glDeleteFramebuffers(1, &uiRenderBuffer);
		glGenFramebuffers(1, &uiRenderBuffer);
		glBindFramebuffer(GL_FRAMEBUFFER, uiRenderBuffer);

		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, windowSize.width, windowSize.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, null);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, uiRenderTexture, 0);
		glDrawBuffer(GL_COLOR_ATTACHMENT0);
		
		glBindFramebuffer(GL_FRAMEBUFFER, 0);
		invalidated[RenderState.FrameBuffer] = true;
	}

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
		GLuint vertFrame =
			 compileShader("data/shaders/uiRender.vert", GL_VERTEX_SHADER);

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

		uiRenderMaterial = _build(vertFrame, fragSprite);
		atrRenderTarget = Attr!Vert(uiRenderMaterial);
		uiRenderTextureUniform = uiRenderMaterial.getUniformId("in_tex");

		glDisable(GL_BLEND);
		glcheck();
	}
}