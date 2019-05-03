// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

import std.math;
import std.stdio;

import lanlib.render.camera;
import lanlib.render.material;
import lanlib.render.mesh;

import lanlib.types.matrix;
import lanlib.types.vector;

import lanlib.sys.gl;
import lanlib.sys.input;
import lanlib.sys.sdl;

import derelict.sdl2.image;
import derelict.sdl2.sdl;

int main()
{
	debug {
		writeln("Running Lantana2D in debug mode!");
	}
	auto ww = SDLWindow(720, 512, "Lantana2D");
	auto ii = Input();

	DerelictSDL2Image.load();

	if(!IMG_Init(IMG_INIT_PNG))
	{
		writeln("Failed to initialize SDL_Image");
		return 8;
	}
	scope(exit) IMG_Quit();

	GLuint texture = 0;
	SDL_Surface *tex_surface = IMG_Load("data/sprites/test/test1.png");
	glGenTextures(1, &texture);
	glBindTexture(GL_TEXTURE_2D, texture);

	glTexImage2D(
			GL_TEXTURE_2D, 
			0, GL_RGB8, 
			tex_surface.w, tex_surface.h, 
			0, GL_RGB, 
			GL_UNSIGNED_BYTE, tex_surface.pixels);

	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);

	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, texture);

	Vec2[] verts = [
		Vec2(-.5, -.5),
		Vec2(-.5, 0.5),
		Vec2(0.5, -.5),
		Vec2(0.5, 0.5),
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

	Mesh2D mesh = Mesh2D(verts, UVs, tris);

	int[2] wsize = ww.get_dimensions();

	Vec2 translation = Vec2(0,0);
	Material mat = load_material("data/shaders/test.vert", "data/shaders/test.frag");
	auto pos_uniform = mat.set_param("translate", translation);
	auto res_uniform = mat.set_param("cam_resolution", Res(wsize[0], wsize[1]));
	mat.set_param("uv_offset", Vec2(0,0));
	mat.set_param("scale", Vec2(tex_surface.w, tex_surface.h)*4);
	mat.set_param("cam_position", Vec2(0,0));
	mat.set_param("in_tex", 0);
	
	mat.set_attrib_id("position", 0);
	AttribId pos = mat.get_attrib_id("position");
	assert(pos  == 0);

	mat.set_attrib_id("UV", 1);
	AttribId uv = mat.get_attrib_id("UV");
	assert(uv  == 1);
	
	while(ww.should_run)
	{
		wsize = ww.get_dimensions();
		ww.poll_events(ii);
		mat.set_param(res_uniform, Res(wsize[0], wsize[1]));
		if(ii.is_pressed(Input.Action.LEFT))
		{
			translation.x -= 0.016;
		}
		if(ii.is_pressed(Input.Action.RIGHT))
		{
			translation.x += 0.016;
		}
		if(ii.is_pressed(Input.Action.UP))
		{
			translation.y += 0.016;
		}
		if(ii.is_pressed(Input.Action.DOWN))
		{
			translation.y -= 0.016;
		}

		mat.set_param(pos_uniform, translation);

		ww.begin_frame();

		glcheck();

		glBindBuffer(GL_ARRAY_BUFFER, mesh.vbo_pos);
		glEnableVertexAttribArray(pos);
		glEnableVertexAttribArray(uv);

		glcheck();

		glVertexAttribPointer(pos, 2, GL_FLOAT, GL_FALSE, 0, cast(const GLvoid*) 0);
		glVertexAttribPointer(uv, 2, GL_FLOAT, GL_FALSE, 0, cast(const GLvoid*) 0);
		
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mesh.ebo);
		glDrawElements(GL_TRIANGLES, cast(int)mesh.triangles.length*3, GL_UNSIGNED_INT, cast(const GLvoid*)0);

		glDisableVertexAttribArray(pos);
		glDisableVertexAttribArray(uv);
		glcheck();

		ww.end_frame();
	}

	return 0;
}
