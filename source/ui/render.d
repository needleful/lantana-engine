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

import ui.interaction;
import ui.layout;

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

/// The Grand Poobah of UI.
/// It handles all the logic for rendering UI layouts and updating them responsibly.
/// There should be exactly one UIRenderer
public class UIRenderer
{
	/++++++++++++++++++++++++++++++++++++++
		UI Objects and State
	+++++++++++++++++++++++++++++++++++++++/

	/// What UI data was invalidated by a recent change
	/// Invalidation means that data has to be refreshed (expensive)
	enum UIData
	{
		Layout,

		SpriteEBO,
		SpriteEBOPartial,

		TextEBO,
		TextEBOPartial,

		PositionBuffer,
		PositionBufferPartial,

		UVBuffer,
		UVBufferPartial,

		TextAtlas,
		SpriteAtlas,
	}
	private Bitfield!UIData invalidated;

	/// Describes part of an array, marking the start and end
	/// This is used to describe the bounds of buffers that need to be reloaded.
	struct BufferRange
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

	/// A buffer is altered at max once per frame by checking these ranges.
	private BufferRange textInvalid, spriteInvalid, uvInvalid, posInvalid;

	/// The base widget of the UI
	private Widget root;

	/// The size of the UI window
	private RealSize size;

	/// Interactible rectangles
	private Rect[] interactAreas;

	/// Corresponding interactive objects
	private Interactible[] interactibles;

	/// The index of the focused interactive widget
	private InteractibleId focused;

	/++++++++++++++++++++++++++++++++++++++
		FreeType data
	+++++++++++++++++++++++++++++++++++++++/

	// FreeType libraries are used to load fonts
	private FT_Library fontLibrary;

	// Limited to FontId.dt.max fonts (probably 255)
	private FT_Face[] fonts;

	// How many founts are loaded
	private FontId.dt fontCount;

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

	/// 0: text elements
	/// 1: sprite elements
	/// 2: vertex positions, in pixels (all)
	/// 3: UV coordinates (all)
	private GLuint[4] vbo;

	/// 0: text VAO
	/// 1: sprite VAO
	private GLuint[2] vao;

	private ushort[] elemText;
	private ushort[] elemSprite;
	private svec2[] vertpos;
	private vec2[] uvs;

	private Material matText, matSprite;
	private VertAttributes atrText, atrSprite;
	private TextUniforms uniText;
	private SpriteUniforms uniSprite;

	enum atlasSizeText = 256;
	enum atlasSizeSprite = 512;
	private TextureAtlas!(GlyphId, ubyte) atlasText;
	private TextureAtlas!(SpriteId, AlphaColor) atlasSprite;

	private SpriteId.dt spriteCount;

	// All text is rendered by iterating this list
	private TextMeshRef[] textMeshes;

	/++++++++++++++++++++++++++++++++++++++
		public methods -- basic
	+++++++++++++++++++++++++++++++++++++++/

	public this(RealSize p_windowSize)
	{
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
		size = p_windowSize;
		// Reserving space for 5 fonts by default
		// can go up to FontId.dt.max (probably 255)
		fonts.reserve(5);
		textMeshes.reserve(8);

		FT_Error error = FT_Init_FreeType(&fontLibrary);
		if(error)
		{
			throw new Exception(format("FT failed to init library: %d", error));
		}

		initMaterials();
		initBuffers();

		atlasSprite = TextureAtlas!(SpriteId, AlphaColor)(RealSize(atlasSizeSprite));
		atlasText   = TextureAtlas!(GlyphId, ubyte)(RealSize(atlasSizeText));
		debug
		{
			atlasSprite.texture.blitgrid(color(255,255,0,255));
			atlasText.texture.blitgrid(255);
		}
		invalidated.setAll();

		// Clearing invalidated buffer ranges
		textInvalid.clear();
		spriteInvalid.clear();
		posInvalid.clear();
		uvInvalid.clear();
	}

	public ~this()
	{
		foreach(face; fonts)
		{
			FT_Done_Face(face);
		}
		FT_Done_FreeType(fontLibrary);

		glDeleteVertexArrays(vao.length, vao.ptr);
		glDeleteBuffers(vbo.length, vbo.ptr);
	}

	public void update(float p_delta, Input* p_input)
	{
		if(invalidated[UIData.Layout])
		{
			SizeRequest intrinsics = SizeRequest(Bounds(size.width), Bounds(size.height)); 
			root.layout(this, intrinsics);
			root.prepareRender(this, root.position);
		}

		if(invalidated[UIData.SpriteAtlas])
			atlasSprite.reload();

		if(invalidated[UIData.TextAtlas])
			atlasText.reload();

		// If a buffer is fully invalidated, there's no reason to partially update it

		if(invalidated[UIData.TextEBO])
			replaceBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[0], elemText);
		else if(invalidated[UIData.TextEBOPartial])
			updateBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[0], elemText, textInvalid);

		if(invalidated[UIData.SpriteEBO])
			replaceBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[1], elemSprite);
		else if(invalidated[UIData.SpriteEBOPartial])
			updateBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[1], elemSprite, spriteInvalid);

		if(invalidated[UIData.PositionBuffer])
			replaceBuffer(GL_ARRAY_BUFFER, vbo[2], vertpos);
		else if(invalidated[UIData.PositionBufferPartial])
			updateBuffer(GL_ARRAY_BUFFER, vbo[2], vertpos, posInvalid);

		if(invalidated[UIData.UVBuffer])
			replaceBuffer(GL_ARRAY_BUFFER, vbo[3], uvs);
		else if(invalidated[UIData.UVBufferPartial])
			updateBuffer(GL_ARRAY_BUFFER, vbo[3], uvs, uvInvalid);

		invalidated.clear();
		
		// Clearing invalidated buffer ranges
		textInvalid.clear();
		spriteInvalid.clear();
		posInvalid.clear();
		uvInvalid.clear();

		// Get interaction
		if(interactAreas.length > 0)
		{
			bool intersect = false;
			foreach(i, const ref Rect r; interactAreas)
			{
				if(r.contains(p_input.mouse_position))
				{
					intersect = true;
					if(interactibles[focused])
					{
						interactibles[focused].unfocus();
					}
					focused = InteractibleId(cast(ubyte)i);
					interactibles[focused].focus();
					break;
				}
			}

			if(!intersect && interactibles[focused])
			{
				interactibles[focused].unfocus();
			}
			else if(p_input.is_just_pressed(Input.Action.UI_INTERACT))
			{
				interactibles[focused].interact();
			}
		}
	}

	public void render() 
	{
		glEnable(GL_BLEND);
		glDisable(GL_DEPTH_TEST);
		// Render sprites
		matSprite.enable();
		glBindVertexArray(vao[1]);

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, atlasSprite.texture.id);

		matSprite.setUniform(uniSprite.in_tex, 0);
		matSprite.setUniform(uniSprite.translation, ivec2(0));
		matSprite.setUniform(uniSprite.cam_resolution, uvec2(size.width, size.height));
		
		glDrawElements(
			GL_TRIANGLES,
			cast(int) elemSprite.length,
			GL_UNSIGNED_SHORT,
			cast(void*) 0);

		glcheck();

		// Render text
		matText.enable();
		glBindVertexArray(vao[0]);

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, atlasText.texture.id);

		matText.setUniform(uniText.in_tex, 0);
		matText.setUniform(uniText.cam_resolution, uvec2(size.width, size.height));
		// TODO: text color should be configurable
		matText.setUniform(uniText.color, vec3(1, 0.7, 1));
		
		foreach(ref tm; textMeshes)
		{
			matText.setUniform(uniText.translation, tm.translation);
			glDrawElements(
				GL_TRIANGLES,
				cast(int) floor(tm.length*tm.visiblePortion)*6,
				GL_UNSIGNED_SHORT,
				cast(void*) (tm.offset*ushort.sizeof));
		}

		glBindVertexArray(0);

		glcheck();
	}

	public void setRootWidget(Widget p_root)
	{
		root = p_root;
		invalidated[UIData.Layout] = true;
	}

	public void setRootWidgets(Widget[] p_widgets)
	{
		setRootWidget(new HodgePodge(p_widgets));
	}

	public void setSize(RealSize p_size)
	{
		size = p_size;
		invalidated[UIData.Layout] = true;
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

		invalidated[UIData.SpriteAtlas] = true;

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

	/// Add a quad for a sprite (not sized yet)
	public ushort[] addSpriteQuad(SpriteId p_sprite)
	{
		assert(p_sprite in atlasSprite.map);

		// The uv positions are set by other functions, 
		// so they can stay (0,0) right now
		ushort vertStart = cast(ushort)vertpos.length;
		vertpos.length += 4;

		// The UVs must be set, though
		ushort uvstart = cast(ushort)uvs.length;
		assert(uvstart == vertStart);
		uvs.length += 4;

		TextureNode* node = atlasSprite.map[p_sprite];

		// UV start, normalized
		vec2 uv_pos = vec2(node.position.x, node.position.y);
		uv_pos.x /= atlasSprite.texture.size.width;
		uv_pos.y /= atlasSprite.texture.size.height;

		// UV offset, normalized
		vec2 uv_off = vec2(node.size.width, node.size.height);

		uv_off.x /= atlasSprite.texture.size.width;
		uv_off.y /= atlasSprite.texture.size.height;

		// Quads are laid out in space like so:
		// 1-------3   /\ +y
		// |       |   |
		// |       |   |
		// 0-------2   |
		// -------------> +x
		// With vertex indeces in this order:
		// 		{0, 2, 1}
		// 		{1, 2, 3}
		// This applies to both texture UV and screen position.
		uvs[uvstart..uvstart+4] = [
			uv_pos,
			uv_pos + vec2(0, uv_off.y),
			uv_pos + vec2(uv_off.x, 0),
			uv_pos + uv_off
		];

		ulong elemStart = elemSprite.length;
		elemSprite.length += 6;

		elemSprite[elemStart..elemStart+6]= [
			cast(ushort)(vertStart+0), 
			cast(ushort)(vertStart+2), 
			cast(ushort)(vertStart+1),

			cast(ushort)(vertStart+1), 
			cast(ushort)(vertStart+2), 
			cast(ushort)(vertStart+3)
		];

		invalidated[UIData.UVBuffer] = true;
		invalidated[UIData.SpriteEBO] = true;

		return elemSprite[elemStart..elemStart+6];
	}

	/// Set the size of the quad (while removing translation)
	public void setQuadSize(ushort[] p_vertices, RealSize p_size)  nothrow
	{
		assert(p_vertices.length == 6);

		// Consult the diagram in addSpriteQuad for explanation
		ushort quadStart = p_vertices[0];
		vertpos[quadStart] = svec(0,0);
		vertpos[quadStart + 1] = svec(0, p_size.height);
		vertpos[quadStart + 2] = svec(p_size.width, 0);
		vertpos[quadStart + 3] = svec(p_size.width, p_size.height);

		posInvalid.apply(quadStart, quadStart + 4);
		invalidated[UIData.PositionBufferPartial] = true;
	}

	public void translateQuad(ushort[] p_vertices, svec2 p_translation)  nothrow
	{
		assert(p_vertices.length == 6);
		ushort quadStart = p_vertices[0];

		vertpos[quadStart] += p_translation;
		vertpos[quadStart + 1] += p_translation;
		vertpos[quadStart + 2] += p_translation;
		vertpos[quadStart + 3] += p_translation;

		posInvalid.apply(quadStart, quadStart + 4);
		invalidated[UIData.PositionBufferPartial] = true;
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

	public TextMeshRef* addTextMesh(FontId p_font, string p_text, bool p_dynamicSize) nothrow
	{
		import std.uni: isWhite;

		// Calculate number of quads to add
		ushort quads = 0;
		foreach(c; p_text)
		{
			if(!c.isWhite())
			{
				quads += 1;
			}
		}
		// If a dynamically sized string, allocate 150% of the current size
		auto vertspace = p_dynamicSize? cast(ushort)(quads*1.5) : quads;

		// Set fields in the TextMeshRef
		textMeshes ~= TextMeshRef();
		TextMeshRef* tm = &textMeshes[$-1];
		tm.length = cast(ushort)(quads);
		tm.capacity = vertspace;
		tm.offset = cast(ushort)elemText.length;
		tm.visiblePortion = 1;

		elemText.length += 6*vertspace;
		elemText[tm.offset] = cast(ushort)vertpos.length;

		vertpos.length += 4*vertspace;
		uvs.length += 4*vertspace;

		assert(uvs.length == vertpos.length);

		setTextMesh(tm, p_font, p_text);

		invalidated[UIData.UVBuffer] = true;
		invalidated[UIData.PositionBuffer] = true;
		invalidated[UIData.TextEBO] = true;

		return tm;
	}

	public void setTextMesh(TextMeshRef* p_mesh, FontId p_font, string p_text) nothrow
	{
		import std.uni: isWhite;

		ushort oldCount = p_mesh.length;

		ushort quads = 0;
		foreach(c; p_text)
		{
			if(!c.isWhite())
			{
				quads += 1;
			}
		}
		assert(quads <= p_mesh.capacity, "Tried to resize text, but it was too large");
		p_mesh.length = cast(ushort)(quads);

		// Write the buffers
		svec2 pen = svec(0,0);

		FT_Face face = fonts[p_font];

		// Bounds of the entire text box
		ivec2 bottom_left = ivec2(int.max, int.max);
		ivec2 top_right = ivec2(int.min, int.min);

		auto ebostart = p_mesh.offset;
		auto vertstart = elemText[ebostart];

		auto eboQuad = ebostart;
		auto vertQuad = vertstart;

		GlyphId g;
		g.font = p_font;

		foreach(c; p_text)
		{
			g.glyph = c;

			FT_UInt charindex = FT_Get_Char_Index(face, c);
			FT_Load_Glyph(face, charindex, FT_LOAD_DEFAULT);

			auto ftGlyph = face.glyph;

			if(c == '\n')
			{
				// Because the coordinates are from the bottom left, we have to raise the rest of the mesh
				pen.x = 0;
				auto lineHeight = face.size.metrics.height >> 6;
				foreach(v; elemText[p_mesh.offset]..vertQuad)
				{
					vertpos[v].y += lineHeight;
				}
				top_right.y += lineHeight;
				continue;
			}
			else if(c.isWhite())
			{
				pen += svec(
					ftGlyph.advance.x >> 6, 
					ftGlyph.advance.y >> 6);
				continue;
			}

			// The glyph is not whitespace, add its vertices
			RealSize size = RealSize(ftGlyph.bitmap.pitch, ftGlyph.bitmap.rows);

			bool newGlyph;
			TextureNode* node = atlasText.getAtlasSpot(g, size, &newGlyph);
			if(newGlyph)
			{
				FT_Render_Glyph(face.glyph, FT_RENDER_MODE_NORMAL);
				atlasText.texture.blit(node.size, node.position, ftGlyph.bitmap.buffer);
				invalidated[UIData.TextAtlas] = true;
			}

			// 1-------3   /\ +y
			// |       |   |
			// |       |   |
			// 0-------2   |
			// -------------> +x	
			// 		{0, 2, 1}
			// 		{1, 2, 3}

			svec2 left = svec(ftGlyph.bitmap_left, 0);
			svec2 right = svec(ftGlyph.bitmap_left + ftGlyph.bitmap.width, 0);
			svec2 bottom = svec(0, ftGlyph.bitmap_top - ftGlyph.bitmap.rows);
			svec2 top = svec(0, ftGlyph.bitmap_top);

			vertpos[vertQuad..vertQuad+4] = [
				pen.add(left).add(bottom),
				pen.add(left).add(top),
				pen.add(right).add(bottom),
				pen.add(right).add(top)
			];

			ivec2 blchar = vertpos[vertQuad];
			ivec2 trchar = vertpos[vertQuad+3];

			bottom_left = vmin(bottom_left, blchar);
			top_right = vmax(top_right, trchar);

			// UV start, normalized
			vec2 uv_pos = vec2(node.position.x, node.position.y);
			uv_pos.x /= atlasText.texture.size.width;
			uv_pos.y /= atlasText.texture.size.height;

			// UV offset, normalized
			vec2 uv_off = vec2(node.size.width, node.size.height);

			uv_off.x /= atlasText.texture.size.width;
			uv_off.y /= atlasText.texture.size.height;

			// FreeType blits text upside-down relative to images
			uvs[vertQuad..vertQuad+4] = [
				uv_pos + vec2(0, uv_off.y),
				uv_pos,
				uv_pos + uv_off,
				uv_pos + vec2(uv_off.x, 0),
			];

			elemText[eboQuad..eboQuad+6] = [
				cast(ushort)(vertQuad),
				cast(ushort)(vertQuad + 2),
				cast(ushort)(vertQuad + 1),

				cast(ushort)(vertQuad + 1),
				cast(ushort)(vertQuad + 2),
				cast(ushort)(vertQuad + 3),
			];

			vertQuad += 4;
			eboQuad += 6;

			pen += svec(
				ftGlyph.advance.x >> 6, 
				ftGlyph.advance.y >> 6);
		}

		posInvalid.apply(vertstart, vertstart + p_mesh.length*4);
		invalidated[UIData.PositionBufferPartial] = true;

		uvInvalid.apply(vertstart, vertstart + p_mesh.length*4);
		invalidated[UIData.UVBufferPartial] = true;

		textInvalid.apply(ebostart, ebostart + p_mesh.length*6);
		invalidated[UIData.TextEBOPartial] = p_mesh.length > oldCount;

		p_mesh.boundingSize = RealSize(top_right - bottom_left);
	}

	public void translateTextMesh(TextMeshRef* p_text, ivec2 p_translation)  nothrow
	{
		p_text.translation = p_translation;
	}

	/++++++++++++++++++++++++++++++++++++++
		public methods -- interactive objects
	+++++++++++++++++++++++++++++++++++++++/

	public InteractibleId addInteractible(Interactible p_source) nothrow
	{
		assert(interactAreas.length == interactibles.length);
		ubyte id = cast(ubyte) interactAreas.length;

		interactAreas ~= Rect.init;
		interactibles ~= p_source;

		return InteractibleId(id);
	}

	public void setInteractSize(InteractibleId p_id, RealSize p_size) nothrow
	{
		interactAreas[p_id].size = p_size;
	}

	public void setInteractPosition(InteractibleId p_id, ivec2 p_position) nothrow
	{
		interactAreas[p_id].pos = p_position;
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
		uvs.length = 8;
		vertpos.length = 8;

		uvs[0..$] = [
			vec2(0,0),
			vec2(0,1),
			vec2(1,0),
			vec2(1,1),

			vec2(0,0),
			vec2(0,1),
			vec2(1,0),
			vec2(1,1)
		];

		vertpos[0..$] = [
			svec(0, 0),
			svec(0, 256),
			svec(256, 0),
			svec(256, 256),

			svec(256, 256),
			svec(256, 256+1024),
			svec(256+1024, 256),
			svec(256+1024, 256+1024)
		];

		elemText.length = 6;
		elemSprite.length = 6;

		elemText[0..$] = [
			0, 2, 1,
			1, 2, 3
		];

		elemSprite[0..$] = [
			4, 6, 5,
			5, 6, 7
		];

		replaceBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[0], elemText);
		replaceBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[1], elemSprite);
		replaceBuffer(GL_ARRAY_BUFFER, vbo[2], vertpos);
		replaceBuffer(GL_ARRAY_BUFFER, vbo[3], uvs);

		glcheck();

		render();
	}

	/++++++++++++++++++++++++++++++++++++++
		private methods
	+++++++++++++++++++++++++++++++++++++++/

	private void initMaterials()
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

	private void initBuffers()
	{
		// Reserve space for 256 characters
		enum textQuads = 256;
		// Space for 10 sprites
		enum spriteQuads = 10;

		elemText.reserve(6*textQuads);
		elemSprite.reserve(6*spriteQuads);

		vertpos.reserve(4*(textQuads + spriteQuads));
		uvs.reserve(4*(textQuads + spriteQuads));

		glcheck();
		glGenBuffers(vbo.length, vbo.ptr);
		glGenVertexArrays(vao.length, vao.ptr);

		// Text Vertices
		glBindVertexArray(vao[0]);

		glEnableVertexAttribArray(atrText.uv);
		glEnableVertexAttribArray(atrText.position);

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[0]);

		glBindBuffer(GL_ARRAY_BUFFER, vbo[2]);
		glVertexAttribIPointer(
			atrText.position,
			2, GL_SHORT,
			0, 
			cast(void*) 0);

		glBindBuffer(GL_ARRAY_BUFFER, vbo[3]);
		glVertexAttribPointer(
			atrText.uv,
			2, GL_FLOAT,
			GL_FALSE,
			0,
			cast(void*) 0);

		glcheck();

		// Sprite Vertices
		glBindVertexArray(vao[1]);

		glDisableVertexAttribArray(atrText.uv);
		glDisableVertexAttribArray(atrText.position);

		glEnableVertexAttribArray(atrSprite.uv);
		glEnableVertexAttribArray(atrSprite.position);

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[1]);

		glBindBuffer(GL_ARRAY_BUFFER, vbo[2]);
		glVertexAttribIPointer(
			atrSprite.position,
			2, GL_SHORT,
			0, 
			cast(void*) 0);

		glBindBuffer(GL_ARRAY_BUFFER, vbo[3]);
		glVertexAttribPointer(
			atrSprite.uv,
			2, GL_FLOAT,
			GL_FALSE,
			0,
			cast(void*) 0);

		glBindVertexArray(0);

		glDisableVertexAttribArray(atrSprite.uv);
		glDisableVertexAttribArray(atrSprite.position);
	}

	private void replaceBuffer(T)(GLenum p_type, GLuint p_vbo, T[] p_buffer)
	{
		glBindBuffer(p_type, p_vbo);
		glBufferData(
			p_type,
			p_buffer.length*T.sizeof,
			p_buffer.ptr,
			GL_DYNAMIC_DRAW);
	}

	private void updateBuffer(T)(GLenum p_type, GLuint p_vbo, T[] p_buffer, BufferRange p_range)
	{
		assert(p_range.start < p_range.end);
		glBindBuffer(p_type, p_vbo);
		glBufferSubData(
			p_type,
			p_range.start*T.sizeof,
			(p_range.end - p_range.start)*T.sizeof,
			&p_buffer[p_range.start]);
	}
}