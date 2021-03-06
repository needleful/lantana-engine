// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.ui.view;

import std.format;
import std.math:floor;
debug import std.stdio;

import derelict.freetype;

import gl3n.linalg: vec2, vec3, Vector;
import lantana.types;
import lantana.input;
import lantana.render.gl;
import lantana.render.material;
import lantana.render.textures;

import lantana.ui.interaction;
import lantana.ui.render;
import lantana.ui.widgets;

/// Index into EBOs
alias ebo_t = uint;

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
	// In linear space for now
	vec3 color;
	// (between 0 and 1) the proportion of characters visible.
	float visiblePortion;
	// Offset within the EBO
	ebo_t offset;
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

	this(int p_start, int p_end)  
	{
		start = p_start;
		end = p_end;
	}

	void clear()   
	{
		start = uint.max;
		end = uint.min;
	}

	void apply(BufferRange rhs)  
	{
		apply(rhs.start, rhs.end);
	}

	void apply(uint p_start, uint p_end)  
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

	package ebo_t[] elemText;
	package ebo_t[] elemSprite;
	package ivec2[] vertpos;
	package vec2[] uvs;

	/// A buffer is altered at max once per frame by checking these ranges.
	package BufferRange textInvalid, spriteInvalid, uvInvalid, posInvalid;

	public this(UIRenderer p_renderer, Rect p_rect) 
	{
		renderer = p_renderer;
		rect = p_rect;
		invalidated.setAll();
		textMeshes.reserve(8);
	}

	public this(UIView p_view, Rect p_rect) 
	{
		parent = p_view;
		renderer = p_view.renderer;
		invalidated.setAll();
		textMeshes.reserve(8);
	}

	public ~this() 
	{
		clearData();
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

		RealSize cs = root.layout(p_request);
		prepareRender();

		invalidated[ViewState.Layout] = false;
		return cs;
	}

	public void prepareRender()
	{
		root.prepareRender(ivec2(0,0));
	}

	package int updateBuffers()
	{
		int updated = 0;
		if(invalidated.realValue() == 0)
		{
			// Nothing to update
			return 0;
		}

		// If a buffer is fully invalidated, there's no reason to partially update it
		if(invalidated[ViewState.TextEBO])
		{
			replaceBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[0], elemText);
			updated++;
		}
		else if(invalidated[ViewState.TextEBOPartial])
		{
			updateBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[0], elemText, textInvalid);
			updated++;
		}

		if(invalidated[ViewState.SpriteEBO])
		{
			replaceBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[1], elemSprite);
			updated++;
		}
		else if(invalidated[ViewState.SpriteEBOPartial])
		{
			updateBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[1], elemSprite, spriteInvalid);
			updated++;
		}

		if(invalidated[ViewState.PositionBuffer])
		{
			replaceBuffer(GL_ARRAY_BUFFER, vbo[2], vertpos);
			updated++;
		}
		else if(invalidated[ViewState.PositionBufferPartial])
		{
			updateBuffer(GL_ARRAY_BUFFER, vbo[2], vertpos, posInvalid);
			updated++;
		}

		if(invalidated[ViewState.UVBuffer])
		{
			replaceBuffer(GL_ARRAY_BUFFER, vbo[3], uvs);
			updated++;
		}
		else if(invalidated[ViewState.UVBufferPartial])
		{
			updateBuffer(GL_ARRAY_BUFFER, vbo[3], uvs, uvInvalid);
			updated++;
		}

		clearBufferInvalidation();
		return updated;
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
			GL_UNSIGNED_INT,
			cast(void*) 0);

		glcheck();

		// Render text
		renderer.matText.enable();
		glBindVertexArray(vao[0]);

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, renderer.atlasText.texture.id);

		renderer.matText.setUniform(renderer.uniText.in_tex, 0);
		renderer.matText.setUniform(renderer.uniText.cam_resolution, wsize);
		
		foreach(ref tm; textMeshes)
		{
			Rect textRect = Rect(rect.pos+translation+tm.translation, tm.boundingSize);
			if(!textRect.intersects(rect))
			{
				continue;
			}

			renderer.matText.setUniform(renderer.uniText.translation, textRect.pos);
			renderer.matText.setUniform(renderer.uniText.color, tm.color);
			//assert(tm.color.y > 0, "uniforms not properly set on this one");
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

	public Widget getRootWidget()
	{
		return root;
	}

	public UIView addView(Rect p_rect) 
	{
		UIView v = new UIView(this, p_rect);
		renderer.views ~= v;
		children ~= v;
		if(renderer.initialized)
		{
			v.initBuffers();
		}
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

	public ivec2 getTranslation()
	{
		return translation;
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
		//printT("UIView % %", cast(void*)this, rect);
	}

	/++++++++++++++++++++++++++++++++++++++
		public methods -- interactive objects
	+++++++++++++++++++++++++++++++++++++++/

	public InteractibleId addInteractible(Interactible p_source) 
	{
		assert(interactAreas.length == interactibles.length);
		auto id = cast(InteractibleId.dt) interactAreas.length;

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

	public bool getFocusedObject(ivec2 p_point, out InteractibleId id, short priority = short.max)
	{
		if(interactAreas.length == 0)
		{
			return false;
		}

		bool found = false;
		foreach(i, const Rect r; interactAreas)
		{
			if(r.contains(p_point - translation))
			{
				if(interactibles[i].priority() == priority)
				{
					found = true;
					id = InteractibleId(cast(InteractibleId.dt)i);
					break;
				}
				else if(!found 
					|| (found && interactibles[id].priority() < interactibles[i].priority()))
				{
					id = InteractibleId(cast(InteractibleId.dt)i);
					found = true;
				}
			}
		}
		return found;
	}

	public Interactible getInteractible(InteractibleId p_id)
	{
		return interactibles[p_id];
	}

	public MeshRef addSpriteQuad(SpriteId p_sprite) 
	{
		assert(p_sprite in renderer.atlasSprite.map);

		TextureNode* node = renderer.atlasSprite.map[p_sprite];

		// The positions are set by other functions, 
		// so they can stay (0,0) right now
		ebo_t vertStart = cast(ebo_t)vertpos.length;
		vertpos.addSpace(4);

		// The UVs must be set, though
		ebo_t uvstart = cast(ebo_t)uvs.length;
		assert(uvstart == vertStart);
		bool uvRealloc = uvs.addSpace(4);

		setQuadUV(uvstart, Rect(node.position, node.size));

		size_t elemStart = elemSprite.length;
		bool elemRealloc = elemSprite.addSpace(6);

		elemSprite[elemStart..elemStart+6] = [
			0, 2, 1,
			1, 2, 3
		];
		elemSprite[elemStart..elemStart+6] += vertStart;

		if(uvRealloc) invalidated[ViewState.UVBuffer] = true;
		if(elemRealloc) 
		{
			invalidated[ViewState.SpriteEBO] = true;
		}
		else
		{
			invalidated[ViewState.SpriteEBOPartial] = true;
			spriteInvalid.apply(cast(uint) elemStart, cast(uint)elemStart + 6);
		}
		return MeshRef(cast(uint)elemStart, 2, 4);
	}

	private void setQuadUV(ebo_t p_start, Rect p_rect) 
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
		vertpos[quadStart] = ivec2(0,0);
		vertpos[quadStart + 1] = ivec2(0, p_size.height);
		vertpos[quadStart + 2] = ivec2(p_size.width, 0);
		vertpos[quadStart + 3] = ivec2(p_size.width, p_size.height);

		invalidated[ViewState.PositionBufferPartial] = true;
		posInvalid.apply(quadStart, quadStart + 4);
	}

	public void setLineQuad(MeshRef p_mesh, ivec2 p_start, ivec2 p_end, float p_thickness)
	{
		auto quadstart = elemSprite[p_mesh.start];
		ivec2 dir = p_start - p_end;
		vec2 orth = vec2(-dir.y, dir.x).normalized*p_thickness;
		vertpos[quadstart..quadstart+4] = 
		[
			p_start,
			p_start + ivec2(cast(int)orth.x, cast(int)orth.y),
			p_end,
			p_end + ivec2(cast(int)orth.x, cast(int)orth.y)
		];
		invalidated[ViewState.PositionBufferPartial] = true;
		posInvalid.apply(quadstart, quadstart + 4);
	}

	public void setSprite(MeshRef p_mesh, SpriteId p_sprite) 
	{
		assert(p_mesh.tris == 2);
		TextureNode* node = renderer.atlasSprite.map[p_sprite];
		setQuadUV(elemSprite[p_mesh.start], Rect(node.position, node.size));
	}

	public MeshRef addPatchRect(SpriteId p_sprite, Pad p_pad) 
	{
		uint vertstart = cast(uint)vertpos.length;
		uint uvstart = cast(uint)uvs.length;

		assert(vertstart == uvstart);

		vertpos.addSpace(16);
		uvs.addSpace(16);

		setPatchRectUV(vertstart, p_sprite, p_pad);

		uint elemstart = cast(uint)elemSprite.length;
		elemSprite.addSpace(18*3);

		uint v = vertstart;

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
			ivec2(0,          0),
			ivec2(0,          p_pad.bottom),
			ivec2(p_pad.left, 0),
			ivec2(p_pad.left, p_pad.bottom),

			ivec2(0,          topbar),
			ivec2(0,          p_size.height),
			ivec2(p_pad.left, topbar),
			ivec2(p_pad.left, p_size.height),

			ivec2(rightbar,     0),
			ivec2(rightbar,     p_pad.bottom),
			ivec2(p_size.width, 0),
			ivec2(p_size.width, p_pad.bottom),

			ivec2(rightbar,     topbar),
			ivec2(rightbar,     p_size.height),
			ivec2(p_size.width, topbar),
			ivec2(p_size.width, p_size.height),
		];
	}

	/// p_count is the number of vertices to change
	/// Assumes the mesh is continuous
	public void translateMesh(MeshRef p_mesh, ivec2 p_translation) 
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
		TextMesh* tm = textMeshes.append(TextMesh());
		tm.length = cast(ushort)(quads);
		tm.capacity = vertspace;
		tm.offset = cast(uint)elemText.length;
		tm.visiblePortion = 1;

		bool eboRealloc = elemText.addSpace(6*vertspace);
		elemText[tm.offset] = cast(ebo_t)vertpos.length;

		bool vertRealloc = vertpos.addSpace(4*vertspace);
		bool uvRealloc = uvs.addSpace(4*vertspace);

		assert(uvs.length == vertpos.length);

		auto id = TextId(cast(uint)textMeshes.length - 1);
		setTextMesh(id, p_font, p_text, Bounds.none, true);

		if(uvRealloc) invalidated[ViewState.UVBuffer] = true;
		if(vertRealloc) invalidated[ViewState.PositionBuffer] = true;
		if(eboRealloc) invalidated[ViewState.TextEBO] = true;

		return id;
	}

	public void setTextMesh(TextId p_id, FontId p_font, string p_text, Bounds p_width=Bounds.none, bool p_forceEBOUpdate = false) 
	{
		TextMesh* mesh = &textMeshes[p_id];
		import std.uni: isWhite;

		ushort quads = 0;
		foreach(c; p_text)
		{
			if(!c.isWhite())
			{
				quads += 1;
			}
		}
		assert(quads <= mesh.capacity, "Tried to resize text, but it was too large");
		ushort oldLength = mesh.length;
		mesh.length = cast(ushort)(quads);

		FT_Face face = renderer.fonts[p_font];

		// Bounds of the entire text box
		int leftBound = int.max;
		int rightBound = int.min;

		auto ebostart = mesh.offset;
		auto vertstart = elemText[ebostart];

		auto eboQuad = ebostart;
		auto vertQuad = vertstart;

		GlyphId g;
		g.font = p_font;
		uint lineHeight = cast(uint)(face.size.metrics.height >> 6);
		uint baseline = cast(uint)((-face.size.metrics.descender) >> 6);
		uint lineCount = 1;

		// Write the buffers
		ivec2 pen = ivec2(0,baseline);
		foreach(i, c; p_text)
		{
			if(c == '\n')
			{
				lineCount++;
				// Because the coordinates are from the bottom left, we have to raise the rest of the mesh
				pen.x = 0;
				foreach(v; elemText[mesh.offset]..vertQuad)
				{
					vertpos[v].y += lineHeight;
				}
				continue;
			}

			FT_UInt charindex = FT_Get_Char_Index(face, c);
			FT_Load_Glyph(face, charindex, FT_LOAD_DEFAULT);

			auto ftGlyph = face.glyph;

			if(c.isWhite())
			{
				pen += ivec2(
					cast(int)(ftGlyph.advance.x >> 6), 
					cast(int)(ftGlyph.advance.y >> 6));

				//get the size of the following word and break if needed
				uint wordLen = 0;
				foreach(char c2; p_text[i+1..$])
				{
					if(c2.isWhite())
					{
						break;
					}
					charindex = FT_Get_Char_Index(face, c2);
					FT_Load_Glyph(face, charindex, FT_LOAD_DEFAULT);
					ftGlyph = face.glyph;

					wordLen += 10;// ftGlyph.advance.x >> 6;
				}

				if(pen.x + wordLen > p_width.max)
				{
					lineCount++;
					pen.x = 0;
					foreach(v; elemText[mesh.offset]..vertQuad)
					{
						vertpos[v].y += lineHeight;
					}
				}
				continue;
			}

			g.glyph = c;

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

			ivec2 left = ivec2(ftGlyph.bitmap_left, 0);
			ivec2 right = ivec2(ftGlyph.bitmap_left + ftGlyph.bitmap.width, 0);
			ivec2 bottom = ivec2(0, ftGlyph.bitmap_top - ftGlyph.bitmap.rows);
			ivec2 top = ivec2(0, ftGlyph.bitmap_top);

			vertpos[vertQuad..vertQuad+4] = [
				pen + left + bottom,
				pen + left + top,
				pen + right + bottom,
				pen + right + top
			];

			ivec2 blchar = vertpos[vertQuad];
			ivec2 trchar = vertpos[vertQuad+3];

			leftBound = leftBound < blchar.x ? leftBound : blchar.x;
			rightBound = rightBound > trchar.x ? rightBound : trchar.x;

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

			pen += ivec2(
				cast(int)(ftGlyph.advance.x >> 6), 
				cast(int)(ftGlyph.advance.y >> 6));
		}

		posInvalid.apply(vertstart, vertstart + mesh.length*4);
		invalidated[ViewState.PositionBufferPartial] = true;

		uvInvalid.apply(vertstart, vertstart + mesh.length*4);
		invalidated[ViewState.UVBufferPartial] = true;

		textInvalid.apply(ebostart, ebostart + mesh.length*6);
		invalidated[ViewState.TextEBOPartial] = p_forceEBOUpdate || (mesh.length != oldLength);

		mesh.boundingSize = RealSize(rightBound - leftBound, lineCount*lineHeight);
	}
	
	public void translateTextMesh(TextId p_id, ivec2 p_translation)  
	{
		textMeshes[p_id].translation = p_translation;
	}

	public void setTextColor(TextId p_id, vec3 p_color)
	{
		textMeshes[p_id].color = p_color;
	}

	public RealSize textBoundingBox(TextId p_id)
	{
		return textMeshes[p_id].boundingSize;
	}

	public void setTextVisiblePercent(TextId p_id, float p_vis)
	{
		textMeshes[p_id].visiblePortion = p_vis;
	}

	public ivec2 getCursorPosition(TextId p_id, string p_text, uint p_index)
	{
		import std.uni: isWhite;
		uint meshIndex = p_index*4 + elemText[textMeshes[p_id].offset];

		ivec2 offset = ivec2(-2, -4);

		if(p_text.length == 0)
		{
			return offset;
		}

		foreach(i; 0..p_index)
		{
			if(p_text[i].isWhite())
			{
				meshIndex -= 4;
			}
		}
		if(p_index == p_text.length)
		{
			meshIndex -= 2;
			offset.x = 0;
		}
		else if(p_text[p_index].isWhite())
		{
			meshIndex -= 2;
			offset.x = 0;
		}

		ivec2 pos = vertpos[meshIndex] + offset;
		return pos;
	}

	package void initBuffers() 
	{
		elemText.reserve(6);
		elemSprite.reserve(6);
		vertpos.reserve(4);
		uvs.reserve(4);
		glGenBuffers(vbo.length, vbo.ptr);
		glGenVertexArrays(vao.length, vao.ptr);

		// Text Vertices
		glBindVertexArray(vao[0]);

		renderer.atrText.enable();

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[0]);

		glBindBuffer(GL_ARRAY_BUFFER, vbo[2]);
		glVertexAttribIPointer(
			renderer.atrText.position,
			2, GL_INT,
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

		renderer.atrText.disable();
		renderer.atrSprite.enable();

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[1]);

		glBindBuffer(GL_ARRAY_BUFFER, vbo[2]);
		glVertexAttribIPointer(
			renderer.atrSprite.position,
			2, GL_INT,
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

		renderer.atrSprite.disable();
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
		glcheck();
		glBindBuffer(p_type, p_vbo);
		glBufferData(
			p_type,
			p_buffer.capacity*T.sizeof,
			p_buffer.ptr,
			GL_DYNAMIC_DRAW);
		glcheck();
	}

	private void updateBuffer(T)(GLenum p_type, GLuint p_vbo, T[] p_buffer, BufferRange p_range)
	{
		assert(p_range.start < p_range.end);
		glcheck();
		glBindBuffer(p_type, p_vbo);
		glBufferSubData(
			p_type,
			p_range.start*T.sizeof,
			(p_range.end - p_range.start)*T.sizeof,
			&p_buffer[p_range.start]);
		glcheck();
	}

	package void clearData() 
	{
		textMeshes.clear();
		elemSprite.clear();
		elemText.clear();
		vertpos.clear();
		uvs.clear();
		interactibles.clear();
		interactAreas.clear();
		invalidated.setAll();
	}
}
