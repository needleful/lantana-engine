// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

import std.format;
import std.stdio;

import derelict.sdl2.image;
import derelict.sdl2.sdl;

import lanlib.math.vector;
import lanlib.sys.gl;
import lanlib.sys.sdl;

import logic.input;
import render.material;
import render.mesh;

// Currently used to test random things
int main()
{
	auto screen_w = 720;
	auto screen_h = 512;

	SDLWindow ww = SDLWindow(screen_w, screen_h, "Lantana Editor");
	ww.grab_mouse(false);

	Input ii = Input();

	DerelictSDL2Image.load();

	SDL_Surface* tx_surface;

	IMG_Init(IMG_INIT_PNG);
	scope(exit) IMG_Quit();
	tx_surface = IMG_Load("data/test/needleful.png");

	glcheck();

	if(!tx_surface)
	{
		printf("Failed to load image: %d\n", IMG_GetError());
		return 1;
	}
	scope(exit) SDL_FreeSurface(tx_surface);

	GLuint texture;
	glGenTextures(1, &texture);

	glBindTexture(GL_TEXTURE_2D, texture);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

	glTexImage2D (GL_TEXTURE_2D,
			0, GL_RGB8,
			tx_surface.w, tx_surface.h,
			0, GL_RGB,
			GL_UNSIGNED_BYTE, tx_surface.pixels);

	glcheck();
	
	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, texture);

	Vec2[] verts = [
		Vec2(-100, -100),
		Vec2(-100, 100),
		Vec2(100, -100),
		Vec2(100, 100),
	];

	Vec2[] UVs = [
		Vec2(0, 1),
		Vec2(0, 0),
		Vec2(1, 1),
		Vec2(1, 0),
	];

	Tri[] tris = [
		Tri(0, 3, 1),
		Tri(0, 2, 3)
	];

	Mesh2D mesh = Mesh2D(verts, UVs, tris);
	Material mat2d = load_material("data/shaders/screenspace2d.vert", "data/shaders/sprite2d.frag");
	
	auto wsize = ww.get_dimensions();
	mat2d.set_param("translate", iVec2(0,0));
	mat2d.set_param("scale", Vec2(tx_surface.w, tx_surface.h));
	mat2d.set_param("cam_position", Vec2(0,0));
	mat2d.set_param("cam_resolution", iVec2(wsize[0], wsize[1]));
	//mat2d.set_param("in_tex", 0);
	//glActiveTexture(GL_TEXTURE0);
	//glBindTexture(GL_TEXTURE_2D, texture);

	glcheck();

	VaoId vao;
	{
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
		glVertexAttribPointer(pos, 3, GL_FLOAT, GL_FALSE, 0, cast(const(GLvoid*)) 0);
		glcheck();

		//AttribId uv = mat2d.get_attrib_id("UV");
		//assert(uv.handle >= 0);
		//glBindBuffer(GL_ARRAY_BUFFER, mesh.uv);
		//glEnableVertexAttribArray(uv);
		//glVertexAttribPointer(uv, 2, GL_FLOAT, GL_FALSE, 0, cast(const(GLvoid*)) 0);

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mesh.ebo);

		glBindVertexArray(0);
		glcheck();
	}

	//Render2D r2d = Render2D(mat2d);

	glDisable(GL_CULL_FACE);

	while(!(ww.state & WindowState.CLOSED))
	{
		ww.poll_events(ii);

		ww.begin_frame();
		glcheck();
		{
			mat2d.enable();
			glBindVertexArray(vao);
			glDrawElements(GL_TRIANGLES, cast(int)mesh.triangles.length*3, GL_UNSIGNED_INT, cast(GLvoid*) 0);
			glBindVertexArray(0);
		}
		glcheck();

		ww.end_frame();
	}
	return 0;
}