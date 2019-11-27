// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0


import std.format;
import std.stdio;

import deimos.freeimage;
import derelict.freetype;
import derelict.sdl2.sdl;

import gl3n.linalg;

import lanlib.sys.gl;
import lanlib.sys.sdl;

import logic.input;

import render.Material;
import render.mesh;

import test.sprite;
import ui.text;

int main()
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

	auto atlas = new TextAtlas("data/fonts/averia/Averia-Light.ttf", 32, 256, 256);

	atlas.blitgrid();
	auto message = atlas.add_text("You've been working hard;\nI find that to be of great interest now.", ivec2(0, 128));
	auto message2 = atlas.add_text(r"[]{|\][11425239p8()*3590198-25", ivec2(0,54), vec3(0, 0.5, 0.5));

	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, atlas.atlas_id);

	ivec2[] verts = [
		ivec2(0, 256),
		ivec2(0, 512),
		ivec2(256, 256),
		ivec2(256, 512),
	];

	vec2[] UVs = [
		vec2(0, 1),
		vec2(0, 0),
		vec2(1, 1),
		vec2(1, 0),
	];

	uint[] tris = [
		0, 3, 1,
		0, 2, 3
	];
	glcheck();
	Mesh2D mesh = Mesh2D(verts, UVs, tris);
	GLuint vao_text;
	// Create VAO
	{
		glcheck();

		glGenVertexArrays(1, &vao_text);
		glBindVertexArray(vao_text);

		AttribId pos = atlas.text_mat.get_attrib_id("position");
		assert(pos.handle() >= 0);
		glBindBuffer(GL_ARRAY_BUFFER, mesh.pos);
		glEnableVertexAttribArray(pos);
		glVertexAttribIPointer(pos, 2, GL_INT, 0, cast(const(GLvoid*)) 0);

		AttribId uv = atlas.text_mat.get_attrib_id("UV");
		assert(uv.handle >= 0);
		glBindBuffer(GL_ARRAY_BUFFER, mesh.uv);
		glEnableVertexAttribArray(uv);
		glVertexAttribPointer(uv, 2, GL_FLOAT, GL_FALSE, 0, cast(const(GLvoid*)) 0);

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mesh.ebo);

		glBindVertexArray(0);
		glcheck();
	}


	auto wsize = ww.get_dimensions();
	printf("Screen: %u, %u\n", wsize[0], wsize[1]);

	uint frame = 0;
	while(!(ww.state & WindowState.CLOSED))
	{
		ww.poll_events(ii);

		if(ww.state & WindowState.RESIZED)
		{
			wsize = ww.get_dimensions();
			atlas.text_mat.set_uniform("cam_resolution", uvec2(wsize[0], wsize[1]));
		}

		ww.begin_frame();

		glcheck();
		{
			glDisable(GL_CULL_FACE);
			glEnable(GL_BLEND);
			glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

			atlas.text_mat.enable();
			glActiveTexture(GL_TEXTURE0);
			glBindTexture(GL_TEXTURE_2D, atlas.atlas_id);

			atlas.text_mat.set_uniform("translate", ivec2(0,0));
			atlas.text_mat.set_uniform("cam_resolution", uvec2(wsize[0], wsize[1]));
			atlas.text_mat.set_uniform("cam_position", ivec2(0, 0));
			atlas.text_mat.set_uniform("in_tex", 0);
			atlas.text_mat.set_uniform("color", vec3(0.9, 0.5, 0.7));

			glBindVertexArray(vao_text);
			glDrawElements(GL_TRIANGLES, cast(int)mesh.triangles.length*3, GL_UNSIGNED_INT, cast(GLvoid*) 0);
			glBindVertexArray(0);
		}
		glcheck();

		atlas.render(wsize);

		ww.end_frame();
	}
	return 0;
	//*/
}