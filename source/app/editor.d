// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

import std.format;
import std.stdio;

import deimos.freeimage;
import derelict.sdl2.sdl;

import lanlib.math.vector;
import lanlib.sys.gl;
import lanlib.sys.sdl;

import logic.input;
import render.material;
import render.mesh;

struct Texture
{
	uint width, height;
	GLuint id;
	ubyte* pixels;

	@disable this();

	this(string png_filename)
	{
		FBITMAP *bitmap = FreeImage_Load(FIF_PNG, png_filename, PNG_DEFAULT);

		glcheck();

		if(!bitmap)
		{
			printf("Failed to load image: %d\n", IMG_GetError());
		}
		scope(exit) SDL_FreeSurface(tx_surface);

		glGenTextures(1, &id);

		glBindTexture(GL_TEXTURE_2D, id);

		glTexImage2D (GL_TEXTURE_2D,
				0, GL_RGB,
				tx_surface.w, tx_surface.h,
				0, GL_RGB,
				GL_UNSIGNED_BYTE, tx_surface.pixels);

		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

		glcheck();
	}

	~this()
	{
		glDeleteTextures(1, &id);
	}
}
void OnFreeImageError(FREE_IMAGE_FORMAT fif, const char* message) const @nogc nothrow
{
	if(fif != FIF_UNKNOWN)
	{
		printf("FreeImage Format: %s\n", FreeImage_GetFormatFromFIF(fif));
	}
	printf("FreeImage: %s\n", message);
}

// Currently used to test random things
int main()
{
	FreeImage_Initialise(true);
	scope(exit) FreeImage_DeInitialise();
	auto screen_w = 720;
	auto screen_h = 512;

	SDLWindow ww = SDLWindow(screen_w, screen_h, "Lantana Editor");
	ww.grab_mouse(false);

	Input ii = Input();

	DerelictSDL2Image.load();

	IMG_Init(IMG_INIT_PNG);
	scope(exit) IMG_Quit();

	Texture tex = Texture("data/test/needleful.png");
	
	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, tex.id);

	iVec2[] verts = [
		iVec2(100, 100),
		iVec2(100, 371),
		iVec2(371, 100),
		iVec2(371, 371),
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
	VaoId vao;
	// Create VAO and VBOs
	glGenVertexArrays(1, vao.ptr);
	glBindVertexArray(vao);
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

	//Render2D r2d = Render2D(mat2d);

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

		ww.begin_frame();

		glcheck();
		{
			glBindVertexArray(vao);
			glDrawElements(GL_TRIANGLES, cast(int)mesh.triangles.length*3, GL_UNSIGNED_INT, cast(GLvoid*) 0);
			glBindVertexArray(0);
		}
		glcheck();

		ww.end_frame();
	}
	return 0;
}