// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module ui.text;

import std.format;
import std.stdio;

import derelict.freetype;

import gl3n.linalg;

import lanlib.util.gl;
import render.Material;

alias ivec2 = Vector!(int, 2);

struct Rectangle
{
	ivec2 pos;
	ivec2 size;
	this(ivec2 pos, ivec2 size)
	{
		this.pos = pos;
		this.size = size;
	}

	bool holds(ivec2 bounds)
	{
		return bounds.x <= size.x && bounds.y <= size.y;
	}
}

struct ScreenSpaceText
{
	string text;
	ivec2 position;
	vec3 color;

	uint[] elements;
	ivec2[] vertices;
	vec2[] uvs;

	GLuint vao;
	// [0] is elements
	// [1] is vertices
	// [2] is uvs
	GLuint[3] vbo;

	bool visible;

	this(TextAtlas parent, string new_text)
	{
		visible = true;
		this.text = new_text;

		elements.reserve(text.length * 6);
		vertices.reserve(text.length * 4);
		uvs.reserve(text.length * 4);

		glGenBuffers(vbo.length, vbo.ptr);
		
		glGenVertexArrays(1, &vao);
		glBindVertexArray(vao);

		glEnableVertexAttribArray(parent.atr_pos);
		glEnableVertexAttribArray(parent.atr_uv);

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[0]);

		glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
		glVertexAttribIPointer(parent.atr_pos, 2, GL_INT, 0, cast(const(GLvoid*)) 0);

		glBindBuffer(GL_ARRAY_BUFFER, vbo[2]);
		glVertexAttribPointer(parent.atr_uv, 2, GL_FLOAT, GL_FALSE, 0, cast(const(GLvoid*)) 0);

		glBindVertexArray(0);

		glDisableVertexAttribArray(parent.atr_pos);
		glDisableVertexAttribArray(parent.atr_uv);

		debug printf("Created ScreenSpaceText: '%s' (vao %u)\n", text.ptr, vao);
	}

	void reloadBuffers()
	{
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[0]);
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, elements.length*uint.sizeof, elements.ptr, GL_STATIC_DRAW);

		glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
		glBufferData(GL_ARRAY_BUFFER, vertices.length*ivec2.sizeof, vertices.ptr, GL_STATIC_DRAW);

		glBindBuffer(GL_ARRAY_BUFFER, vbo[2]);
		glBufferData(GL_ARRAY_BUFFER, uvs.length*vec2.sizeof, uvs.ptr, GL_STATIC_DRAW);
	}

	~this()
	{
		glDeleteBuffers(vbo.length, vbo.ptr);
		glDeleteVertexArrays(1, &vao);
		debug printf("Deleting ScreenSpaceText: '%s (vao %u)'\n", text.ptr, vao);
	}
}

struct GlyphNode
{
	GlyphNode* left, right;
	Rectangle rec;
	dchar code;

	this(Rectangle rec)
	{
		this.rec = rec;
		left = null;
		right = null;
		code = 0;
	}

	~this()
	{
		debug printf("Deleting glyphnode %c\n", code);
	}
	bool isleaf()
	{
		return left == null && right == null;
	}
	bool empty()
	{
		return code == 0;
	}
}

class TextAtlas
{
	ushort width, height;
	// The ID of the atlas texture
	GLuint atlas_id;
	// The FreeType library loaded
	FT_Library library;
	// The font being used
	FT_Face face;
	// Map of chars to nodes
	GlyphNode*[dchar] charmap;
	// A binary tree of cached glyphs
	GlyphNode *glyphs;
	// The actual bytes of the texture
	ubyte[] texture_data;
	// Text Material
	Material text_mat;
	// The strings handled by this atlas
	ScreenSpaceText[] textboxes;

	struct Uniforms
	{
		UniformId translate,
		cam_resolution,
		cam_position,
		in_tex, 
		color;
	}

	AttribId atr_pos, atr_uv;

	private Uniforms un;

	@disable this();

	this(string font_file, ushort text_pixel_size, ushort width = 1024, ushort height = 1024)
	{
		this.width = width;
		this.height = height;
		texture_data.length = width*height;

		glyphs = new GlyphNode(Rectangle(ivec2(0,0), ivec2(width, height)));
		text_mat = load_Material("data/shaders/screenspace2d.vert", "data/shaders/text2d.frag");
		assert(text_mat.can_render());

		un.translate = text_mat.get_uniform_id("translate");
		un.cam_resolution = text_mat.get_uniform_id("cam_resolution");
		un.cam_position = text_mat.get_uniform_id("cam_position");
		un.in_tex = text_mat.get_uniform_id("in_tex");
		un.color = text_mat.get_uniform_id("color");

		atr_pos = text_mat.get_attrib_id("position");
		atr_uv = text_mat.get_attrib_id("UV");

		glGenTextures(1, &atlas_id);

		glBindTexture(GL_TEXTURE_2D, atlas_id);

		glTexImage2D (GL_TEXTURE_2D,
				0, GL_R8,  // Note that OpenGL does not care what a channel means, if it's a single channel image, it's red.
				width, height,
				0, GL_RED,
				GL_UNSIGNED_BYTE, texture_data.ptr);

		// These have no default values and the texture will just be black if they aren't set
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

		FT_Error error = FT_Init_FreeType(&library);
		if(error)
		{
			throw new Exception(format("FT failed to init library: %d", error));
		}
		error = FT_New_Face(
			library,
			font_file.ptr,
			0,
			&face);
		if ( error == FT_Err_Unknown_File_Format )
		{
			throw new Exception(format("Unsupported font format: %s", font_file));
		}
		else if (error)
		{
			throw new Exception(format("Could not load font: %s.  Error code: %d", font_file, error));
		}

		error = FT_Set_Pixel_Sizes(face, 0, text_pixel_size);

		if (error)
		{
			throw new Exception(format("Could not resize font: %s.  Error code: %d", font_file, error));
		}
	}

	~this() nothrow
	{
		debug puts("Deleting TextAtlas");
		glDeleteTextures(1, &atlas_id);
		FT_Done_Face(face);
		FT_Done_FreeType(library);
	}

	ScreenSpaceText* add_text(string text, ivec2 position = ivec2(0), vec3 color = vec3(1))
	{
		import std.uni;

		textboxes.length += 1;
		textboxes[$-1] = ScreenSpaceText(this, text);

		auto res = &textboxes[$-1];
		res.position = position;
		res.color = color;

		ivec2 pen = ivec2(0, face.height >> 6);
		uint idx_vbo = 0;
		uint idx_ebo = 0;

		foreach(c; text)
		{
			//debug printf("\t %c ++ vbo[%u], ebo[%u]\n", c, idx_vbo, idx_ebo);

			FT_UInt charindex = FT_Get_Char_Index(face, c);
			FT_Load_Glyph(face, charindex, FT_LOAD_DEFAULT);

			auto g = face.glyph;

			if(!c.isWhite())
			{
				GlyphNode* glyph = insertChar(c);
				
				ivec2 left = ivec2(g.bitmap_left, 0);
				ivec2 right = ivec2(g.bitmap_left + g.bitmap.width, 0);
				ivec2 bottom = ivec2(0, g.bitmap_top - g.bitmap.rows);
				ivec2 top = ivec2(0, g.bitmap_top);

				res.vertices.length += 4;
				res.vertices[idx_vbo..idx_vbo+4] = [
					pen + left + bottom,
					pen + left + top,
					pen + right + bottom,
					pen + right + top
				];

				//debug printf("\t   ++ [%d, %d] to [%d, %d]\n", 
				//	res.vertices[idx_vbo].x, res.vertices[idx_vbo].y,
				//	res.vertices[idx_vbo+3].x, res.vertices[idx_vbo+3].y);

				vec2 uv_pos = vec2(glyph.rec.pos.x, glyph.rec.pos.y);
				uv_pos.x /= width;
				uv_pos.y /= height;

				vec2 uv_size = vec2(glyph.rec.size.x, glyph.rec.size.y);
				uv_size.x /= width;
				uv_size.y /= height;

				res.uvs.length += 4;
				res.uvs[idx_vbo..idx_vbo+4] = [
					uv_pos + vec2(0, uv_size.y),
					uv_pos,
					uv_pos + uv_size,
					uv_pos + vec2(uv_size.x, 0)
				];

				res.elements.length += 6;
				res.elements[idx_ebo..idx_ebo+6] = [
					idx_vbo + 0, idx_vbo + 1, idx_vbo + 2,
					idx_vbo + 1, idx_vbo + 3, idx_vbo + 2
				];

				//debug printf("\t   ++ face: {%u, -> %u}\n", res.elements[idx_ebo], res.elements[idx_ebo]);

				idx_vbo = cast(uint) res.vertices.length;
				idx_ebo = cast(uint) res.elements.length;

				pen.x += g.advance.x >> 6;
				pen.y += g.advance.y >> 6;
			}
			else if(c == '\n')
			{
				//debug puts("\t <newline>");
				pen.x = 0;
				pen.y -= face.height >> 6;
			}
			else
			{
				//debug puts("\t <whitespace>");
				pen.x += g.advance.x >> 6;
				pen.y += g.advance.y >> 6;
			}

		}
		//printf("%u vertices, %u UVs, %u elements\n", res.vertices.length, res.uvs.length, res.elements.length);

		glBindTexture(GL_TEXTURE_2D, atlas_id);
		glTexImage2D (GL_TEXTURE_2D,
				0, GL_R8,
				width, height,
				0, GL_RED,
				GL_UNSIGNED_BYTE, texture_data.ptr);


		res.reloadBuffers();

		glcheck();

		return res;
	}

	void render(int[2] wsize)
	{
		glDisable(GL_CULL_FACE);
		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

		glcheck();

		text_mat.enable();
		glBindTexture(GL_TEXTURE_2D, atlas_id);
		glActiveTexture(GL_TEXTURE0);

		glcheck(); 

		text_mat.set_uniform(un.in_tex, 0);
		text_mat.set_uniform(un.cam_resolution, uvec2(wsize[0], wsize[1]));
		text_mat.set_uniform(un.cam_position, ivec2(0, 0));

		glcheck();

		glEnableVertexAttribArray(atr_pos);
		glEnableVertexAttribArray(atr_uv);

		foreach(ref text; textboxes)
		{
			if(!text.visible)
			{
				continue;
			}
			text_mat.set_uniform(un.translate, text.position);
			text_mat.set_uniform(un.color, text.color);

			glBindVertexArray(text.vao);
			glDrawElements(GL_TRIANGLES, cast(int)text.elements.length, GL_UNSIGNED_INT, cast(GLvoid*) 0);
		}
		glBindVertexArray(0);

		glDisableVertexAttribArray(atr_pos);
		glDisableVertexAttribArray(atr_uv);

		glcheck();
	}

	void blitgrid()
	{

		for(uint row = 1; row < height-1; row ++)
		{
			for(uint col = 1; col < width-1; col++)
			{
				// blacked out
				texture_data[row*width + col] = 0;
			}
		}
		for(uint row = 1; row < height - 1; row++)
		{
			texture_data[row*width] = 0xFF;
			texture_data[row*width + width-1] = 0xFF;

			for(uint col = 32; col < width; col += 32)
			{
				texture_data[row*width + col] = (0x11 + col) & 0xFF;
			}
		}

		for(uint col = 1; col < width - 1; col++)
		{
			texture_data[col] = 0xFF;
			texture_data[(width-1)*width + col] = 0xFF;

			for(uint row = 32; row < height; row += 32)
			{
				texture_data[row*height + col] = (0x11 + row) & 0xFF;
			}
		}
		
		glBindTexture(GL_TEXTURE_2D, atlas_id);
		glTexImage2D (GL_TEXTURE_2D,
				0, GL_R8,
				width, height,
				0, GL_RED,
				GL_UNSIGNED_BYTE, texture_data.ptr);
	}

	// Find a spot and insert a character
	GlyphNode* insertChar(dchar c)
	{
		GlyphNode* _insert(GlyphNode *g, dchar c)
		{
			// Occupied
			if(!g.empty())
			{
				return null;
			}
			if(g.isleaf())
			{
				ivec2 size = ivec2(face.glyph.bitmap.pitch, face.glyph.bitmap.rows);

				ivec2 space = g.rec.size - size;

				// Perfect size
				if(space.x == 0 && space.y == 0)
				{
					g.code = c;
					return g;
				}

				// Too small
				if(space.x < 0 || space.y < 0)
				{
					return null;
				}

				// Prefer splitting vertically
				if(space.y >= space.x)
				{
					// left is on the bottom (same position up to the vertical size)
					g.left = new GlyphNode(Rectangle(
						g.rec.pos, 
						ivec2(g.rec.size.x, size.y)));

					g.right = new GlyphNode(Rectangle(
						ivec2(g.rec.pos.x, g.rec.pos.y + size.y),
						ivec2(g.rec.size.x, space.y)));

					return _insert(g.left, c);
				}
				else
				{
					// left is on the left (same pos up to horizontal size)
					g.left = new GlyphNode(Rectangle(
						g.rec.pos, 
						ivec2(size.x, g.rec.size.y)));

					g.right = new GlyphNode(Rectangle(
						ivec2(g.rec.pos.x + size.x, g.rec.pos.y),
						ivec2(space.x, g.rec.size.y)));

					return _insert(g.left, c);
				}
			}
			else
			{
				if(g.left.code && g.right.code)
				{
					g.code = 1;
				}

				auto ptr = _insert(g.left, c);
				if(ptr == null)
				{
					ptr = _insert(g.right, c);
				}
				return ptr;
			}

		}

		if(c in charmap)
		{
			return charmap[c];
		}

		FT_UInt charindex = FT_Get_Char_Index(face, c);
		FT_Error err = FT_Load_Glyph(face, charindex, FT_LOAD_DEFAULT);
		if(err)
		{
			throw new Exception(format("FreeType could not load char %c.  Error code: %d", c, err));
		}

		err = FT_Render_Glyph(face.glyph, FT_RENDER_MODE_NORMAL);
		if(err)
		{
			throw new Exception(format("FreeType could not render char %c.  Error code: %d", c, err));
		}

		auto glyph = _insert(glyphs, c);
		assert(glyph != null, format("Failed to insert char: %c", c));

		if(glyph != null)
		{
			charmap[c] = glyph;
			blit(face.glyph.bitmap, glyph.rec.pos);
		}
		return glyph;
	}

	void insertChars(string str)
	{
		foreach(c; str)
		{
			insertChar(c);
		}
		glBindTexture(GL_TEXTURE_2D, atlas_id);
		glTexImage2D (GL_TEXTURE_2D,
				0, GL_R8,
				width, height,
				0, GL_RED,
				GL_UNSIGNED_BYTE, texture_data.ptr);
	}

	void blit(FT_Bitmap bm, ivec2 pen)
	{
		uint pitch = bm.pitch;
		// Only 8-bit images
		assert(pitch == bm.width);

		for(uint row = 0; row < bm.rows; row++)
		{
			for(uint col = 0; col < bm.width; col++)
			{
				int source = row*bm.pitch + col;
				int target = (pen.y + row)*width + (col + pen.x);

				assert(target >= 0 && target < width*height, format("Invalid index %d [valid: 0 to %u]", target, width*height));

				texture_data[target] = bm.buffer[source];
			}
		}
	}
}