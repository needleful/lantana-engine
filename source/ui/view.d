// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module ui.view;

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
import ui.render;

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

package enum ViewState
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

public final class UIView
{
	public UIRenderer renderer;
	/// The base widget of the UI
	private Widget root;

	package Rect rect;

	/// What UI data was invalidated by a recent change
	/// Invalidation means that data has to be refreshed (expensive)
	package Bitfield!ViewState invalidated;

	// All text is rendered by iterating this list
	package TextMeshRef[] textMeshes;

	/// Interactible rectangles
	package Rect[] interactAreas;

	/// Corresponding interactive objects
	package Interactible[] interactibles;

	/// 0: text elements
	/// 1: sprite elements
	/// 2: vertex positions, in pixels (all)
	/// 3: UV coordinates (all)
	package GLuint[4] vbo;

	/// 0: text VAO
	/// 1: sprite VAO
	package GLuint[2] vao;

	package ushort[] elemText;
	package ushort[] elemSprite;
	package svec2[] vertpos;
	package vec2[] uvs;

	/// A buffer is altered at max once per frame by checking these ranges.
	package BufferRange textInvalid, spriteInvalid, uvInvalid, posInvalid;

	public this(UIRenderer p_renderer, Rect p_rect) nothrow
	{
		renderer = p_renderer;
		rect = p_rect;
		initBuffers();
		invalidated.setAll();
		textMeshes.reserve(8);
	}

	public ~this() nothrow
	{
		glDeleteVertexArrays(vao.length, vao.ptr);
		glDeleteBuffers(vbo.length, vbo.ptr);
	}

	public RealSize updateLayout() nothrow
	{
		return updateLayout(SizeRequest(Bounds(rect.size.width), Bounds(rect.size.height)));
	}

	public RealSize updateLayout(SizeRequest p_request) nothrow
	{
		if(!invalidated[ViewState.Layout])
			return rect.size;

		RealSize cs = root.layout(this, p_request);
		root.prepareRender(this, ivec2(0,0));

		invalidated[ViewState.Layout] = false;

		return cs;
	}

	package void updateBuffers()
	{
		// If a buffer is fully invalidated, there's no reason to partially update it
		if(invalidated[ViewState.TextEBO])
			replaceBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[0], elemText);
		else if(invalidated[ViewState.TextEBOPartial])
			updateBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[0], elemText, textInvalid);

		if(invalidated[ViewState.SpriteEBO])
			replaceBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[1], elemSprite);
		else if(invalidated[ViewState.SpriteEBOPartial])
			updateBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[1], elemSprite, spriteInvalid);

		if(invalidated[ViewState.PositionBuffer])
			replaceBuffer(GL_ARRAY_BUFFER, vbo[2], vertpos);
		else if(invalidated[ViewState.PositionBufferPartial])
			updateBuffer(GL_ARRAY_BUFFER, vbo[2], vertpos, posInvalid);

		if(invalidated[ViewState.UVBuffer])
			replaceBuffer(GL_ARRAY_BUFFER, vbo[3], uvs);
		else if(invalidated[ViewState.UVBufferPartial])
			updateBuffer(GL_ARRAY_BUFFER, vbo[3], uvs, uvInvalid);
	}

	package void render(RealSize p_windowSize)
	{
		uvec2 wsize = uvec2(p_windowSize.width, p_windowSize.height);
		glScissor(rect.pos.x, rect.pos.y, rect.size.width, rect.size.height);
		glEnable(GL_BLEND);
		glDisable(GL_DEPTH_TEST);
		// Render sprites
		renderer.matSprite.enable();
		glBindVertexArray(vao[1]);

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, renderer.atlasSprite.texture.id);

		renderer.matSprite.setUniform(renderer.uniSprite.in_tex, 0);
		renderer.matSprite.setUniform(renderer.uniSprite.translation, rect.pos);
		renderer.matSprite.setUniform(renderer.uniSprite.cam_resolution, wsize);
		
		glDrawElements(
			GL_TRIANGLES,
			cast(int) elemSprite.length,
			GL_UNSIGNED_SHORT,
			cast(void*) 0);

		glcheck();

		// Render text
		renderer.matText.enable();
		glBindVertexArray(vao[0]);

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, renderer.atlasText.texture.id);

		renderer.matText.setUniform(renderer.uniText.in_tex, 0);
		renderer.matText.setUniform(renderer.uniText.cam_resolution, wsize);
		// TODO: text color should be configurable
		renderer.matText.setUniform(renderer.uniText.color, vec3(1, 0.7, 1));
		
		foreach(ref tm; textMeshes)
		{
			renderer.matText.setUniform(renderer.uniText.translation, tm.translation+rect.pos);
			glDrawElements(
				GL_TRIANGLES,
				cast(int) floor(tm.length*tm.visiblePortion)*6,
				GL_UNSIGNED_SHORT,
				cast(void*) (tm.offset*ushort.sizeof));
		}

		glBindVertexArray(0);

		glcheck();
	}

	public void setRootWidget(Widget p_root) nothrow
	{
		clearData();
		root = p_root;
		root.initialize(renderer, this);
		invalidated[ViewState.Layout] = true;
	}

	public void setRect(Rect p_rect) nothrow
	{
		if(p_rect == rect)
		{
			return;
		}
		rect = p_rect;
		invalidated[ViewState.Layout] = true;
	}

	public ivec2 position() nothrow
	{
		return rect.pos;
	}

	public RealSize size() nothrow
	{
		return rect.size;
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

	package bool getFocusedObject(Input* p_input, ref InteractibleId id)
	{
		// Get interaction
		if(interactAreas.length > 0)
		{
			foreach(i, const ref Rect r; interactAreas)
			{
				if(r.contains(p_input.mouse_position))
				{
					id = InteractibleId(cast(ubyte)i);
					return true;
				}
			}
		}
		return false;
	}

	public ushort[] addSpriteQuad(SpriteId p_sprite) nothrow
	{
		assert(p_sprite in renderer.atlasSprite.map);

		TextureNode* node = renderer.atlasSprite.map[p_sprite];

		// UV start, normalized
		vec2 uv_pos = vec2(node.position.x, node.position.y);
		uv_pos.x /= renderer.atlasSprite.texture.size.width;
		uv_pos.y /= renderer.atlasSprite.texture.size.height;

		// UV offset, normalized
		vec2 uv_size = vec2(node.size.width, node.size.height);

		uv_size.x /= renderer.atlasSprite.texture.size.width;
		uv_size.y /= renderer.atlasSprite.texture.size.height;

		// The positions are set by other functions, 
		// so they can stay (0,0) right now
		ushort vertStart = cast(ushort)vertpos.length;
		vertpos.length += 4;

		// The UVs must be set, though
		ushort uvstart = cast(ushort)uvs.length;
		assert(uvstart == vertStart);
		uvs.length += 4;


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
			uv_pos + vec2(0, uv_size.y),
			uv_pos + vec2(uv_size.x, 0),
			uv_pos + uv_size
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

		invalidated[ViewState.UVBuffer] = true;
		invalidated[ViewState.SpriteEBO] = true;
		return elemSprite[elemStart..elemStart+6];
	}

	public void setQuadSize(ushort[] p_vertices, RealSize p_size) nothrow
	{
		assert(p_vertices.length == 6);

		// Consult the diagram in addSpriteQuad for explanation
		ushort quadStart = p_vertices[0];
		vertpos[quadStart] = svec(0,0);
		vertpos[quadStart + 1] = svec(0, p_size.height);
		vertpos[quadStart + 2] = svec(p_size.width, 0);
		vertpos[quadStart + 3] = svec(p_size.width, p_size.height);

		invalidated[ViewState.PositionBufferPartial] = true;
		posInvalid.apply(quadStart, quadStart + 4);
	}

	public void translateQuad(ushort[] p_vertices, svec2 p_translation) nothrow
	{
		assert(p_vertices.length == 6);
		ushort quadStart = p_vertices[0];

		vertpos[quadStart] += p_translation;
		vertpos[quadStart + 1] += p_translation;
		vertpos[quadStart + 2] += p_translation;
		vertpos[quadStart + 3] += p_translation;

		invalidated[ViewState.PositionBufferPartial] = true;
		posInvalid.apply(quadStart, quadStart + 4);
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

		invalidated[ViewState.UVBuffer] = true;
		invalidated[ViewState.PositionBuffer] = true;
		invalidated[ViewState.TextEBO] = true;

		return tm;
	}

	public void setTextMesh(TextMeshRef* p_tm, FontId p_font, string p_text) nothrow
	{
		import std.uni: isWhite;

		ushort oldCount = p_tm.length;

		ushort quads = 0;
		foreach(c; p_text)
		{
			if(!c.isWhite())
			{
				quads += 1;
			}
		}
		assert(quads <= p_tm.capacity, "Tried to resize text, but it was too large");
		p_tm.length = cast(ushort)(quads);

		// Write the buffers
		svec2 pen = svec(0,0);

		FT_Face face = renderer.fonts[p_font];

		// Bounds of the entire text box
		ivec2 bottom_left = ivec2(int.max, int.max);
		ivec2 top_right = ivec2(int.min, int.min);

		auto ebostart = p_tm.offset;
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
				foreach(v; elemText[p_tm.offset]..vertQuad)
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
			TextureNode* node = renderer.atlasText.getAtlasSpot(g, size, &newGlyph);
			if(newGlyph)
			{
				FT_Render_Glyph(face.glyph, FT_RENDER_MODE_NORMAL);
				renderer.atlasText.texture.blit(node.size, node.position, ftGlyph.bitmap.buffer);
				renderer.invalidated[AtlasState.Text] = true;
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
			uv_pos.x /= renderer.atlasText.texture.size.width;
			uv_pos.y /= renderer.atlasText.texture.size.height;

			// UV offset, normalized
			vec2 uv_off = vec2(node.size.width, node.size.height);

			uv_off.x /= renderer.atlasText.texture.size.width;
			uv_off.y /= renderer.atlasText.texture.size.height;

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

		posInvalid.apply(vertstart, vertstart + p_tm.length*4);
		invalidated[ViewState.PositionBufferPartial] = true;

		uvInvalid.apply(vertstart, vertstart + p_tm.length*4);
		invalidated[ViewState.UVBufferPartial] = true;

		textInvalid.apply(ebostart, ebostart + p_tm.length*6);
		invalidated[ViewState.TextEBOPartial] = p_tm.length > oldCount;

		p_tm.boundingSize = RealSize(top_right - bottom_left);
	}
	
	public void translateTextMesh(TextMeshRef* p_text, ivec2 p_translation)  nothrow
	{
		p_text.translation = p_translation;
	}


	private void initBuffers() nothrow
	{
		// Reserve space for 256 characters
		enum textQuads = 256;
		// Space for 10 sprites
		enum spriteQuads = 10;

		elemText.reserve(6*textQuads);
		elemSprite.reserve(6*spriteQuads);

		vertpos.reserve(4*(textQuads + spriteQuads));
		uvs.reserve(4*(textQuads + spriteQuads));

		glGenBuffers(vbo.length, vbo.ptr);
		glGenVertexArrays(vao.length, vao.ptr);

		// Text Vertices
		glBindVertexArray(vao[0]);

		glEnableVertexAttribArray(renderer.atrText.uv);
		glEnableVertexAttribArray(renderer.atrText.position);

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[0]);

		glBindBuffer(GL_ARRAY_BUFFER, vbo[2]);
		glVertexAttribIPointer(
			renderer.atrText.position,
			2, GL_SHORT,
			0, 
			cast(void*) 0);

		glBindBuffer(GL_ARRAY_BUFFER, vbo[3]);
		glVertexAttribPointer(
			renderer.atrText.uv,
			2, GL_FLOAT,
			GL_FALSE,
			0,
			cast(void*) 0);

		// Sprite Vertices
		glBindVertexArray(vao[1]);

		glDisableVertexAttribArray(renderer.atrText.uv);
		glDisableVertexAttribArray(renderer.atrText.position);

		glEnableVertexAttribArray(renderer.atrSprite.uv);
		glEnableVertexAttribArray(renderer.atrSprite.position);

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[1]);

		glBindBuffer(GL_ARRAY_BUFFER, vbo[2]);
		glVertexAttribIPointer(
			renderer.atrSprite.position,
			2, GL_SHORT,
			0, 
			cast(void*) 0);

		glBindBuffer(GL_ARRAY_BUFFER, vbo[3]);
		glVertexAttribPointer(
			renderer.atrSprite.uv,
			2, GL_FLOAT,
			GL_FALSE,
			0,
			cast(void*) 0);

		glBindVertexArray(0);

		glDisableVertexAttribArray(renderer.atrSprite.uv);
		glDisableVertexAttribArray(renderer.atrSprite.position);
	}

	package void clearInvalidation() nothrow
	{
		invalidated.clear();
		// Clearing invalidated buffer ranges
		textInvalid.clear();
		spriteInvalid.clear();
		posInvalid.clear();
		uvInvalid.clear();
	}

	private void replaceBuffer(T)(GLenum p_type, GLuint p_vbo, T[] p_buffer) nothrow
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

	private void clearData() nothrow
	{
		textMeshes.clear();
		elemSprite.clear();
		elemText.clear();
		vertpos.clear();
		uvs.clear();
	}
}
