// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

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

struct Texture
{
	FIBITMAP *bitmap;
	GLuint id;

	@disable this();

	this(string filename)
	{
		auto format = FreeImage_GetFileType(filename.ptr);
		bitmap = FreeImage_Load(format, filename.ptr);

		glcheck();

		if(!bitmap)
		{
			printf("Failed to load image: %d\n", filename.ptr);
		}

		glGenTextures(1, &id);

		glBindTexture(GL_TEXTURE_2D, id);

		glTexImage2D (GL_TEXTURE_2D,
				0, GL_RGB,
				width(), height(),
				0, GL_RGB,
				GL_UNSIGNED_BYTE, data());

		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

		glcheck();
	}

	~this() nothrow
	{
		glDeleteTextures(1, &id);
		FreeImage_Unload(bitmap);
	}

	uint width() nothrow
	{
		return FreeImage_GetWidth(bitmap);
	}

	uint height() nothrow
	{
		return FreeImage_GetHeight(bitmap);
	}

	ubyte* data() nothrow
	{
		return FreeImage_GetBits(bitmap);
	}
}

struct TextSystem
{
	FIBITMAP *glyph_atlas;
	GLuint atlas_id;

	@disable this();

	this(string font_file)
	{
		glyph_atlas = FreeImage_AllocateT(FIT_BITMAP, 1024, 1024, 8, 0xFF, 0xFF, 0xFF);
		glGenTextures(1, &atlas_id);

		glBindTexture(GL_TEXTURE_2D, atlas_id);

		glTexImage2D (GL_TEXTURE_2D,
				0, GL_ALPHA,
				FreeImage_GetWidth(glyph_atlas), FreeImage_GetHeight(glyph_atlas),
				0, GL_ALPHA,
				GL_UNSIGNED_BYTE, FreeImage_GetBits(glyph_atlas));

		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	}

	~this() nothrow
	{
		glDeleteTextures(1, &atlas_id);
		FreeImage_Unload(glyph_atlas);
	}

	uint width() nothrow
	{
		return FreeImage_GetWidth(glyph_atlas);
	}

	uint height() nothrow
	{
		return FreeImage_GetHeight(glyph_atlas);
	}

	ubyte* data() nothrow
	{
		return FreeImage_GetBits(glyph_atlas);
	}
}

// Currently used to test random things
int main()
{
	auto screen_w = 720;
	auto screen_h = 512;

	SDLWindow ww = SDLWindow(screen_w, screen_h, "Lantana Editor");
	ww.grab_mouse(false);

	Input ii = Input();

	FreeImage_Initialise(true);
	scope(exit) FreeImage_DeInitialise();
	
	try
	{
		DerelictFT.load();
	}
	catch(derelict.util.exception.SymbolLoadException e)
	{
		// known missing symbols
		if(e.symbolName() != "FT_Stream_OpenBzip2")
		{
			throw e;
		}
	}

	Texture tex = Texture("data/test/needleful.png");
	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, tex.id);

	iVec2[] verts = [
		iVec2(100, 100),
		iVec2(100, 100 + tex.height()),
		iVec2(100 + tex.width(), 100),
		iVec2(100 + tex.width(), 100 + tex.height()),
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
	
	Material mat2d = load_material("data/shaders/screenspace2d.vert", "data/shaders/sprite2d.frag");
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

	auto wsize = ww.get_dimensions();
	printf("Screen: %u, %u\n", wsize[0], wsize[1]);

	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, tex.id);
	mat2d.enable();	
	mat2d.set_param("translate", iVec2(0,0));
	mat2d.set_param("cam_resolution", uVec2(wsize[0], wsize[1]));
	mat2d.set_param("cam_position", iVec2(0, 0));
	mat2d.set_param("in_tex", 0);
	

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