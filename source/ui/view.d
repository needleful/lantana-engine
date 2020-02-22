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
import lanlib.util.printing;
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
private struct TextMesh
{
	// The total bounding box
	RealSize boundingSize;
	// Translation of the mesh
	ivec2 translation;
	// (between 0 and 1) the proportion of characters visible.
	float visiblePortion;
	// Offset within the EBO
	uint offset;
	// Number of quads to render
	ushort length;
	// Amount of quads allocated
	ushort capacity;
}

public struct TextId
{
	mixin StrictAlias!uint;
}

public struct MeshRef
{
	uint start;
	ushort tris, vertices;

	private this(uint p_start, ushort p_tris, ushort p_verts)
	{
		start = p_start;
		tris = p_tris;
		vertices = p_verts;
	}
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

	this(int p_start, int p_end)   @safe
	{
		start = p_start;
		end = p_end;
	}

	void clear()   @safe
	{
		start = uint.max;
		end = uint.min;
	}

	void apply(BufferRange rhs)   @safe
	{
		apply(rhs.start, rhs.end);
	}

	void apply(uint p_start, uint p_end)   @safe
	{
		start = start < p_start? start : p_start;
		end = end > p_end? end : p_end;
	}
}

/// Each UIView is responsible for rendering and processing its elements.
/// A UIView can be the whole window, or contained within a widget such as Scrolled
public final class UIView
{
	/// The parent renderer
	public UIRenderer renderer;

	/// The base widget of the UI
	private Widget root;

	/// Whether to show the view
	private bool visible = true;

	/// Children of the current view
	private UIView[] children;

	/// Parent
	private UIView parent;

	/// The rectangle for scissor clipping
	package Rect rect;

	// Translate the root item against the rectangle
	package ivec2 translation;

	/// What UI data was invalidated by a recent change
	/// Invalidation means that data has to be refreshed (expensive)
	package Bitfield!ViewState invalidated;

	// All text is rendered by iterating this list
	package TextMesh[] textMeshes;

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

	package uint[] elemText;
	package ushort[] elemSprite;
	package svec2[] vertpos;
	package vec2[] uvs;

	/// A buffer is altered at max once per frame by checking these ranges.
	package BufferRange textInvalid, spriteInvalid, uvInvalid, posInvalid;

	public this(UIRenderer p_renderer, Rect p_rect) 
	{
		renderer = p_renderer;
		rect = p_rect;
		initBuffers();
		invalidated.setAll();
		textMeshes.reserve(8);
	}

	public this(UIView p_view, Rect p_rect) 
	{
		parent = p_view;
		renderer = p_view.renderer;
		initBuffers();
		invalidated.setAll();
		textMeshes.reserve(8);
	}

	public ~this() 
	{
		glDeleteVertexArrays(vao.length, vao.ptr);
		glDeleteBuffers(vbo.length, vbo.ptr);
	}

	public void requestUpdate() 
	{
		invalidated[ViewState.Layout] = true;
		if(parent)
		{
			parent.requestUpdate();
		}
	}

	public RealSize updateLayout() 
	{
		return updateLayout(SizeRequest(Bounds(rect.size.width), Bounds(rect.size.height)));
	}

	public RealSize updateLayout(SizeRequest p_request) 
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
		if(invalidated.realValue() == 0)
		{
			// Nothing to update
			return;
		}

		// If a buffer is fully invalidated, there's no reason to partially update it
		if(invalidated[ViewState.TextEBO])
		{
			replaceBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[0], elemText);
		}
		else if(invalidated[ViewState.TextEBOPartial])
		{
			updateBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[0], elemText, textInvalid);
		}

		if(invalidated[ViewState.SpriteEBO])
		{
			replaceBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[1], elemSprite);
		}
		else if(invalidated[ViewState.SpriteEBOPartial])
		{
			updateBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[1], elemSprite, spriteInvalid);
		}

		if(invalidated[ViewState.PositionBuffer])
		{
			replaceBuffer(GL_ARRAY_BUFFER, vbo[2], vertpos);
		}
		else if(invalidated[ViewState.PositionBufferPartial])
		{
			updateBuffer(GL_ARRAY_BUFFER, vbo[2], vertpos, posInvalid);
		}

		if(invalidated[ViewState.UVBuffer])
		{
			replaceBuffer(GL_ARRAY_BUFFER, vbo[3], uvs);
		}
		else if(invalidated[ViewState.UVBufferPartial])
		{
			updateBuffer(GL_ARRAY_BUFFER, vbo[3], uvs, uvInvalid);
		}

		clearBufferInvalidation();
	}

	package void render(RealSize p_windowSize)
	{
		uvec2 wsize = uvec2(p_windowSize.width, p_windowSize.height);
		glScissor(rect.pos.x, rect.pos.y, rect.size.width, rect.size.height);
		// Render sprites
		renderer.matSprite.enable();
		glBindVertexArray(vao[1]);

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, renderer.atlasSprite.texture.id);

		renderer.matSprite.setUniform(renderer.uniSprite.in_tex, 0);
		renderer.matSprite.setUniform(renderer.uniSprite.translation, rect.pos + translation);
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
			renderer.matText.setUniform(renderer.uniText.translation, rect.pos+translation+tm.translation);
			glDrawElements(
				GL_TRIANGLES,
				cast(int) floor(tm.length*tm.visiblePortion)*6,
				GL_UNSIGNED_INT,
				cast(void*) (tm.offset*typeof(tm.offset).sizeof));
		}

		glBindVertexArray(0);

		glcheck();
	}

	public void setRootWidget(Widget p_root) 
	{
		clearData();
		root = p_root;
		root.initialize(renderer, this);
		invalidated[ViewState.Layout] = true;
	}

	public UIView addView(Rect p_rect) 
	{
		UIView v = new UIView(this, p_rect);
		renderer.views ~= v;
		children ~= v;
		return v;
	}

	public void setRect(Rect p_rect) 
	{
		if(p_rect == rect)
		{
			return;
		}
		rect = p_rect;
		invalidated[ViewState.Layout] = true;
	}

	public ivec2 position() 
	{
		return rect.pos;
	}

	public RealSize size() 
	{
		return rect.size;
	}

	public void translate(ivec2 mov) 
	{
		translation += mov;
	}

	public bool isVisible()  @nogc const
	{
		return visible;
	}

	public void setVisible(bool p_vis)  @nogc
	{
		visible = p_vis;
		if(visible)
		{
			invalidated[ViewState.Layout] = true;
		}
		foreach(child; children)
		{
			child.setVisible(p_vis);
		}
	}

	public void print()  @nogc
	{
		printT("UIView % %", cast(void*)this, rect);
	}

	/++++++++++++++++++++++++++++++++++++++
		public methods -- interactive objects
	+++++++++++++++++++++++++++++++++++++++/

	public InteractibleId addInteractible(Interactible p_source) 
	{
		assert(interactAreas.length == interactibles.length);
		ubyte id = cast(ubyte) interactAreas.length;

		interactAreas ~= Rect.init;
		interactibles ~= p_source;

		return InteractibleId(id);
	}

	public void setInteractSize(InteractibleId p_id, RealSize p_size) 
	{
		interactAreas[p_id].size = p_size;
	}

	public void setInteractPosition(InteractibleId p_id, ivec2 p_position) 
	{
		interactAreas[p_id].pos = p_position;
	}

	package bool getFocusedObject(Input* p_input, ref InteractibleId id)
	{
		// TODO: buttons within Scrolled currently don't work. Is it a problem in here?
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

	public MeshRef addSpriteQuad(SpriteId p_sprite) 
	{
		assert(p_sprite in renderer.atlasSprite.map);

		TextureNode* node = renderer.atlasSprite.map[p_sprite];

		// The positions are set by other functions, 
		// so they can stay (0,0) right now
		ushort vertStart = cast(ushort)vertpos.length;
		vertpos.length += 4;

		// The UVs must be set, though
		ushort uvstart = cast(ushort)uvs.length;
		assert(uvstart == vertStart);
		uvs.length += 4;

		setQuadUV(uvstart, Rect(node.position, node.size));

		ulong elemStart = elemSprite.length;
		elemSprite.length += 6;

		elemSprite[elemStart..elemStart+6] = [
			0, 2, 1,
			1, 2, 3
		];
		elemSprite[elemStart..elemStart+6] += vertStart;

		invalidated[ViewState.UVBuffer] = true;
		invalidated[ViewState.SpriteEBO] = true;
		return MeshRef(cast(uint)elemStart, 2, 4);
	}

	private void setQuadUV(uint p_start, Rect p_rect) 
	{
		// UV start, normalized
		vec2 uv_pos = vec2(p_rect.pos.x, p_rect.pos.y);
		uv_pos.x /= renderer.atlasSprite.texture.size.width;
		uv_pos.y /= renderer.atlasSprite.texture.size.height;

		// UV offset, normalized
		vec2 uv_size = vec2(p_rect.size.width, p_rect.size.height);

		uv_size.x /= renderer.atlasSprite.texture.size.width;
		uv_size.y /= renderer.atlasSprite.texture.size.height;

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
		uvs[p_start..p_start+4] = [
			uv_pos,
			uv_pos + vec2(0, uv_size.y),
			uv_pos + vec2(uv_size.x, 0),
			uv_pos + uv_size
		];

		invalidated[ViewState.UVBufferPartial] = true;
		uvInvalid.apply(p_start, p_start + 4);
	}

	public void setQuadSize(MeshRef p_mesh, RealSize p_size) 
	{
		assert(p_mesh.tris == 2);
		// Consult the diagram in addSpriteQuad for explanation
		auto quadStart = elemSprite[p_mesh.start];
		vertpos[quadStart] = svec(0,0);
		vertpos[quadStart + 1] = svec(0, p_size.height);
		vertpos[quadStart + 2] = svec(p_size.width, 0);
		vertpos[quadStart + 3] = svec(p_size.width, p_size.height);

		invalidated[ViewState.PositionBufferPartial] = true;
		posInvalid.apply(quadStart, quadStart + 4);
	}

	public void setSprite(MeshRef p_mesh, SpriteId p_sprite) 
	{
		assert(p_mesh.tris == 2);
		TextureNode* node = renderer.atlasSprite.map[p_sprite];
		setQuadUV(elemSprite[p_mesh.start], Rect(node.position, node.size));
	}

	public MeshRef addPatchRect(SpriteId p_sprite, Pad p_pad) 
	{
		ushort vertstart = cast(ushort)vertpos.length;
		ushort uvstart = cast(ushort)uvs.length;

		assert(vertstart == uvstart);

		vertpos.length += 16;
		uvs.length += 16;

		setPatchRectUV(vertstart, p_sprite, p_pad);

		uint elemstart = cast(uint)elemSprite.length;
		elemSprite.length += 6*9;

		ushort v = vertstart;

		// See comment in setPatchRectUV for diagram
		elemSprite[elemstart..elemstart+18*3] = [
			// 0
			0, 2, 1,
			1, 2, 3,
			// 1
			1, 3, 4,
			4, 3, 6,
			// 2
			4, 6, 5,
			5, 6, 7,
			// 3
			2, 8, 3,
			3, 8, 9,
			// 4
			3, 9, 6,
			6, 9, 12,
			// 5
			6, 12, 7,
			7, 12, 13,
			// 6
			8, 10, 9,
			9, 10, 11,
			// 7
			9, 11, 12,
			12, 11, 14,
			// 8
			12, 14, 13,
			13, 14, 15
		];
		elemSprite[elemstart..elemstart+18*3] += vertstart;

		invalidated[ViewState.UVBuffer] = true;
		invalidated[ViewState.PositionBuffer] = true;
		invalidated[ViewState.SpriteEBO] = true;

		return MeshRef(elemstart, 18, 16);
	}

	public void setPatchRectUV(MeshRef p_mesh, SpriteId p_sprite, Pad p_pad)
	{
		setPatchRectUV(elemSprite[p_mesh.start], p_sprite, p_pad);
	}

	private void setPatchRectUV(uint p_vertstart, SpriteId p_sprite, Pad p_pad) 
	{
		/+
			A biggun!

			5---7--------D---F
			| 2 |   5    | 8 |
			4---6--------C---E
			|   |        |   |
			| 1 |   4    | 7 |
			|   |        |   |
			1---3--------9---B   /\
			| 0 |   3    | 6 |   |
			0---2--------8---A   y+

			x+ ->

			As with quads, elements ordered like so:
			{0, 2, 1}
			{1, 2, 3}
		+/
		TextureNode * node = renderer.atlasSprite.map[p_sprite];

		// Each rectangle has its own position
		ivec2 bot_left = node.position;

		ivec2 top_left = ivec2(
			node.position.x, 
			node.position.y + node.size.height - p_pad.top);

		ivec2 bot_right = ivec2(
			node.position.x + node.size.width - p_pad.right,
			node.position.y);

		ivec2 top_right = ivec2(
			node.position.x + node.size.width - p_pad.right,
			node.position.y + node.size.height - p_pad.top);

		setQuadUV(p_vertstart,   Rect(bot_left,  RealSize(p_pad.left, p_pad.bottom)));
		setQuadUV(p_vertstart+4, Rect(top_left,  RealSize(p_pad.left, p_pad.top)));

		setQuadUV(p_vertstart+8,  Rect(bot_right, RealSize(p_pad.right, p_pad.bottom)));
		setQuadUV(p_vertstart+12, Rect(top_right, RealSize(p_pad.right, p_pad.top)));
	}

	public void setPatchRectSize(MeshRef p_mesh, RealSize p_size, Pad p_pad) 
	{
		/+
			A biggun!

			5---7--------D---F
			| 2 |   5    | 8 |
			4---6--------C---E
			|   |  Inner |   |
			| 1 |   4    | 7 |
			|   |        |   |
			1---3--------9---B   /\
			| 0 |   3    | 6 |   |
			0---2--------8---A   y+

			x+ ->
		+/
		uint vecstart = elemSprite[p_mesh.start];

		int topbar = p_size.height - p_pad.top;
		int rightbar = p_size.width - p_pad.right;

		vertpos[vecstart..vecstart+p_mesh.vertices] = [
			svec(0,          0),
			svec(0,          p_pad.bottom),
			svec(p_pad.left, 0),
			svec(p_pad.left, p_pad.bottom),

			svec(0,          topbar),
			svec(0,          p_size.height),
			svec(p_pad.left, topbar),
			svec(p_pad.left, p_size.height),

			svec(rightbar,     0),
			svec(rightbar,     p_pad.bottom),
			svec(p_size.width, 0),
			svec(p_size.width, p_pad.bottom),

			svec(rightbar,     topbar),
			svec(rightbar,     p_size.height),
			svec(p_size.width, topbar),
			svec(p_size.width, p_size.height),
		];
	}

	/// p_count is the number of vertices to change
	/// Assumes the mesh is continuous
	public void translateMesh(MeshRef p_mesh, svec2 p_translation) 
	{
		auto vert = elemSprite[p_mesh.start];

		vertpos[vert..vert+p_mesh.vertices] += p_translation;

		invalidated[ViewState.PositionBufferPartial] = true;
		posInvalid.apply(vert, vert + p_mesh.vertices);
	}

	public TextId addTextMesh(FontId p_font, string p_text, int allocLen) 
	{
		import std.uni: isWhite;

		// Calculate number of quads to add
		ushort quads = 0;
		if(allocLen < p_text.length)
		{
			foreach(c; p_text)
			{
				if(!c.isWhite())
				{
					quads += 1;
				}
			}
		}
		else
		{
			quads = cast(ushort) allocLen;
		}

		auto vertspace = quads;

		// Set fields in the TextMesh
		textMeshes ~= TextMesh();
		TextMesh* tm = &textMeshes[$-1];
		tm.length = cast(ushort)(quads);
		tm.capacity = vertspace;
		tm.offset = cast(uint)elemText.length;
		tm.visiblePortion = 1;

		elemText.length += 6*vertspace;
		elemText[tm.offset] = cast(ushort)vertpos.length;

		vertpos.length += 4*vertspace;
		uvs.length += 4*vertspace;

		assert(uvs.length == vertpos.length);

		auto id = TextId(cast(uint)textMeshes.length - 1);
		setTextMesh(id, p_font, p_text);

		invalidated[ViewState.UVBuffer] = true;
		invalidated[ViewState.PositionBuffer] = true;
		invalidated[ViewState.TextEBO] = true;

		return id;
	}

	public void setTextMesh(TextId p_id, FontId p_font, string p_text) 
	{
		TextMesh* mesh = &textMeshes[p_id];
		import std.uni: isWhite;

		ushort oldCount = mesh.length;

		ushort quads = 0;
		foreach(c; p_text)
		{
			if(!c.isWhite())
			{
				quads += 1;
			}
		}
		assert(quads <= mesh.capacity, "Tried to resize text, but it was too large");
		mesh.length = cast(ushort)(quads);

		// Write the buffers
		svec2 pen = svec(0,0);

		FT_Face face = renderer.fonts[p_font];

		// Bounds of the entire text box
		ivec2 bottom_left = ivec2(int.max, int.max);
		ivec2 top_right = ivec2(int.min, int.min);

		auto ebostart = mesh.offset;
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
				foreach(v; elemText[mesh.offset]..vertQuad)
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
				vertQuad,
				vertQuad + 2,
				vertQuad + 1,

				vertQuad + 1,
				vertQuad + 2,
				vertQuad + 3,
			];

			vertQuad += 4;
			eboQuad += 6;

			pen += svec(
				ftGlyph.advance.x >> 6, 
				ftGlyph.advance.y >> 6);
		}

		posInvalid.apply(vertstart, vertstart + mesh.length*4);
		invalidated[ViewState.PositionBufferPartial] = true;

		uvInvalid.apply(vertstart, vertstart + mesh.length*4);
		invalidated[ViewState.UVBufferPartial] = true;

		textInvalid.apply(ebostart, ebostart + mesh.length*6);
		invalidated[ViewState.TextEBOPartial] = mesh.length > oldCount;

		mesh.boundingSize = RealSize(top_right - bottom_left);
	}
	
	public void translateTextMesh(TextId p_id, ivec2 p_translation)  
	{
		TextMesh* mesh = &textMeshes[p_id];
		mesh.translation = p_translation;
	}

	public RealSize textBoundingBox(TextId p_id)
	{
		return textMeshes[p_id].boundingSize;
	}

	private void initBuffers() 
	{
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

	package void clearBufferInvalidation() 
	{
		bool layoutInvalid = invalidated[ViewState.Layout];
		invalidated.clear();
		invalidated[ViewState.Layout] = layoutInvalid;
		
		// Clearing invalidated buffer ranges
		textInvalid.clear();
		spriteInvalid.clear();
		posInvalid.clear();
		uvInvalid.clear();
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

	private void clearData() 
	{
		textMeshes.clear();
		elemSprite.clear();
		elemText.clear();
		vertpos.clear();
		uvs.clear();
	}
}
