
module test.font;

import core.stdc.stdlib;
import std.format;
import std.stdio;

import deimos.freeimage;
import derelict.freetype;
import derelict.sdl2.sdl;

import lanlib.math.vector;
import lanlib.sys.gl;
import lanlib.sys.sdl;

import logic.input;
import render.material;
import render.mesh;


struct TextSystem
{
	ushort width, height;
	ubyte *data;
	FT_Library library;
	FT_Face face;
	GLuint atlas_id;

	@disable this();

	// OK let's document the fuck out of these functions
	this(string font_file)
	{
		width = 256;
		height = 256;
		// Allocating a single-channel, 8-bit image
		data = cast(ubyte*)malloc(width*height*ubyte.sizeof);

		glGenTextures(1, &atlas_id);

		glBindTexture(GL_TEXTURE_2D, atlas_id);

		glTexImage2D (GL_TEXTURE_2D,
				0, GL_R8,  // Note that OpenGL does not care what a channel means, if it's a single channel image, it's red.
				width, height,
				0, GL_RED,
				GL_UNSIGNED_BYTE, data);

		// These have no default values and the texture will just be black if they aren't set
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
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

	/// Just to test populating the image texture
	void blittest()
	{

		ubyte *bits = data;

		for(uint row = 1; row < height-1; row ++)
		{
			for(uint col = 1; col < width-1; col++)
			{
				// blacked out
				bits[row*width + col] = 0;
			}
		}
		for(uint row = 0; row < height; row++)
		{
			bits[row*width] = 0xFF;
			bits[row*width + width-1] = 0xFF;

			for(uint col = 32; col < width; col += 32)
			{
				bits[row*width + col] = (0x11 + col) & 0xFF;
			}
		}

		for(uint col = 0; col < width; col++)
		{
			bits[col] = 0xFF;
			bits[(width-1)*width + col] = 0xFF;

			for(uint row = 32; row < height; row += 32)
			{
				bits[row*height + col] = (0x11 + row) & 0xFF;
			}
		}
			
		
		glBindTexture(GL_TEXTURE_2D, atlas_id);
		glTexImage2D (GL_TEXTURE_2D,
				0, GL_R8,
				width, height,
				0, GL_RED,
				GL_UNSIGNED_BYTE, data);
	}

	void blitstring(string str, iVec2 pen)
	{
		foreach(c; str)
		{
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

			iVec2 corner = iVec2(face.glyph.bitmap_left, face.glyph.bitmap_top);
			printf("\t%c Bitmap coords: (%d, %d)\n", c, corner.x, corner.y);
			blit(face.glyph.bitmap, pen + corner);

			pen.x += face.glyph.advance.x >> 6;
			pen.y += face.glyph.advance.y >> 6;
		}
		glBindTexture(GL_TEXTURE_2D, atlas_id);
		glTexImage2D (GL_TEXTURE_2D,
				0, GL_R8,
				width, height,
				0, GL_RED,
				GL_UNSIGNED_BYTE, data);
	}

	// Note: this does NOT reload the texture in OpenGL
	// you need to do that yourself!
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
				int target = (pen.y - row)*width + (col + pen.x);

				assert(target > 0 && target <= width*height, 
					format("Invalid index %d [valid: 0 to %u]", target, width*height));

				data[target] = bm.buffer[source];
			}
		}
	}

	~this() nothrow
	{
		glDeleteTextures(1, &atlas_id);
		free(data);
		FT_Done_Face(face);
		FT_Done_FreeType(library);
	}
}

int testfont()
{

	auto screen_w = 720;
	auto screen_h = 512;

	SDLWindow ww = SDLWindow(screen_w, screen_h, "Lantana Editor");
	ww.grab_mouse(false);

	Input ii = Input();

	try
	{
		DerelictFT.load();
	}
	catch(derelict.util.exception.SymbolLoadException e)
	{
		// FT_Stream_OpenBzip2 is a known missing symbol
		if(e.symbolName() != "FT_Stream_OpenBzip2")
		{
			throw e;
		}
	}

	// Handling text
	TextSystem text = TextSystem("data/fonts/averia/Averia-Italic.ttf");

	text.blittest();
	text.blitstring("good day, world!", iVec2(12, 128));

	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, text.atlas_id);

	iVec2[] verts = [
		iVec2(100, 100),
		iVec2(100, 356),
		iVec2(356, 100),
		iVec2(356, 356),
	];

	Vec2[] UVs = [
		Vec2(0, 0),
		Vec2(0, 1),
		Vec2(1, 0),
		Vec2(1, 1),
	];

	Tri[] tris = [
		Tri(0, 3, 1),
		Tri(0, 2, 3)
	];
	
	glcheck();
	
	Material mat2d = load_material("data/shaders/screenspace2d.vert", "data/shaders/text2d.frag");
	assert(mat2d.can_render());

	Mesh2D mesh = Mesh2D(verts, UVs, tris);
	VaoId vao_sprite;
	// Create VAO and VBOs
	glGenVertexArrays(1, vao_sprite.ptr);
	glBindVertexArray(vao_sprite);
	glcheck();

	AttribId pos = mat2d.get_attrib_id("position");
	assert(pos.handle() >= 0);
	glBindBuffer(GL_ARRAY_BUFFER, mesh.pos);
	glcheck();
	glEnableVertexAttribArray(pos);
	glcheck();
	glVertexAttribIPointer(pos, 2, GL_INT, 0, cast(const(GLvoid*)) 0);
	glcheck();

	AttribId uv = mat2d.get_attrib_id("UV");
	assert(uv.handle >= 0);
	glBindBuffer(GL_ARRAY_BUFFER, mesh.uv);
	glEnableVertexAttribArray(uv);
	glVertexAttribPointer(uv, 2, GL_FLOAT, GL_FALSE, 0, cast(const(GLvoid*)) 0);

	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mesh.ebo);

	glBindVertexArray(0);
	glcheck();

	glDisable(GL_CULL_FACE);
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

	auto wsize = ww.get_dimensions();
	printf("Screen: %u, %u\n", wsize[0], wsize[1]);

	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, text.atlas_id);
	mat2d.enable();	
	mat2d.set_param("translate", iVec2(0,0));
	mat2d.set_param("cam_resolution", uVec2(wsize[0], wsize[1]));
	mat2d.set_param("cam_position", iVec2(0, 0));
	mat2d.set_param("in_tex", 0);
	mat2d.set_param("color", Vec3(0.9, 0.5, 0.7));
	
	while(!(ww.state & WindowState.CLOSED))
	{
		ww.poll_events(ii);

		if(ww.state & WindowState.RESIZED)
		{
			wsize = ww.get_dimensions();
			mat2d.set_param("cam_resolution", uVec2(wsize[0], wsize[1]));
		}

		ww.begin_frame();

		glcheck();
		{
			glBindVertexArray(vao_sprite);
			glDrawElements(GL_TRIANGLES, cast(int)mesh.triangles.length*3, GL_UNSIGNED_INT, cast(GLvoid*) 0);
			glBindVertexArray(0);
		}
		glcheck();

		ww.end_frame();
	}
	return 0;
}
	