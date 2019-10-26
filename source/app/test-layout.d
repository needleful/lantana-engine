// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module test.layout;

import std.format;
import std.stdio;

import derelict.freetype;

import lanlib.math.vector;
import lanlib.sys.gl;

import render.material;

struct Rectangle
{
	iVec2 pos;
	iVec2 size;
	this(iVec2 pos, iVec2 size)
	{
		this.pos = pos;
		this.size = size;
	}

	bool holds(iVec2 bounds)
	{
		return bounds.x <= size.x && bounds.y <= size.y;
	}
}

struct ScreenSpaceText
{
	string text;
	uint[] elements;
	iVec2[] vertices;
	Vec2[] uvs;
	// buffers[0] is vao
	// buffers[1] is elements
	// buffers[2] is vertices
	// buffers[3] is uvs
	GLuint[4] buffers;

	@disable this();

	this(string new_text, TextAtlas* atlas)
	{
		this.text = new_text;

		elements.length = text.length * 6;
		vertices.length = text.length * 4;
		uvs.length = text.length * 4;

		glGenBuffers(buffers.length, buffers.ptr);
	}

	~this()
	{
		glDeleteBuffers(buffers.length, buffers.ptr);
	}
}

struct GlyphNode
{
	GlyphNode* left, right;
	Rectangle rec;
	dchar code;

	@disable this();
	this(Rectangle rec)
	{
		this.rec = rec;
		left = null;
		right = null;
		code = 0;
	}

	~this()
	{
		printf("Deleting glyphnode %c\n", code);
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

struct TextAtlas
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
	// Text material
	Material text_mat;

	@disable this();

	this(string font_file, ushort width = 1024, ushort height = 1024)
	{
		this.width = width;
		this.height = height;
		texture_data.length = width*height;
		glyphs = new GlyphNode(Rectangle(iVec2(0,0), iVec2(width, height)));
		text_mat = load_material("data/shaders/screenspace2d.vert", "data/shaders/text2d.frag");

		assert(text_mat.can_render());

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

		error = FT_Set_Pixel_Sizes(face, 0, 32);  // 32 pixels is decently readable on my monitor.  Should test.

		if (error)
		{
			throw new Exception(format("Could not resize font: %s.  Error code: %d", font_file, error));
		}
	}

	~this() nothrow
	{
		glDeleteTextures(1, &atlas_id);
		FT_Done_Face(face);
		FT_Done_FreeType(library);
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
				iVec2 size = iVec2(face.glyph.bitmap.pitch, face.glyph.bitmap.rows);

				iVec2 space = g.rec.size - size;

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
						iVec2(g.rec.size.x, size.y)));

					g.right = new GlyphNode(Rectangle(
						iVec2(g.rec.pos.x, g.rec.pos.y + size.y),
						iVec2(g.rec.size.x, space.y)));

					return _insert(g.left, c);
				}
				else
				{
					// left is on the left (same pos up to horizontal size)
					g.left = new GlyphNode(Rectangle(
						g.rec.pos, 
						iVec2(size.x, g.rec.size.y)));

					g.right = new GlyphNode(Rectangle(
						iVec2(g.rec.pos.x + size.x, g.rec.pos.y),
						iVec2(space.x, g.rec.size.y)));

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

	void blit(FT_Bitmap bm, iVec2 pen)
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