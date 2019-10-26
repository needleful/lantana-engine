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

import test.sprite;
import test.font;
import test.layout;

int main()
{
	//return testfont();
	///*
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

	auto atlas = new TextAtlas!(256, 256)("data/fonts/averia/Averia-Regular.ttf");

	atlas.blitgrid();
	atlas.insertChars("There is much to be said about our current predicament; however, I find that to be of little interest now.");

	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, atlas.atlas_id);

	iVec2[] verts = [
		iVec2(100, 100),
		iVec2(100, 356),
		iVec2(356, 100),
		iVec2(356, 356),
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
	
	glcheck();
	
	Material mat2d = load_material("data/shaders/screenspace2d.vert", "data/shaders/text2d.frag");
	assert(mat2d.can_render());

	Mesh2D mesh = Mesh2D(verts, UVs, tris);
	VaoId vao_text;
	// Create VAO
	{
		glcheck();
		glGenVertexArrays(1, vao_text.ptr);
		glBindVertexArray(vao_text);

		AttribId pos = mat2d.get_attrib_id("position");
		assert(pos.handle() >= 0);
		glBindBuffer(GL_ARRAY_BUFFER, mesh.pos);
		glEnableVertexAttribArray(pos);
		glVertexAttribIPointer(pos, 2, GL_INT, 0, cast(const(GLvoid*)) 0);

		AttribId uv = mat2d.get_attrib_id("UV");
		assert(uv.handle >= 0);
		glBindBuffer(GL_ARRAY_BUFFER, mesh.uv);
		glEnableVertexAttribArray(uv);
		glVertexAttribPointer(uv, 2, GL_FLOAT, GL_FALSE, 0, cast(const(GLvoid*)) 0);

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mesh.ebo);

		glBindVertexArray(0);
		glcheck();
	}

	glDisable(GL_CULL_FACE);
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

	auto wsize = ww.get_dimensions();
	{
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, atlas.atlas_id);

		printf("Screen: %u, %u\n", wsize[0], wsize[1]);
		mat2d.enable();	
		mat2d.set_param("translate", iVec2(0,0));
		mat2d.set_param("cam_resolution", uVec2(wsize[0], wsize[1]));
		mat2d.set_param("cam_position", iVec2(0, 0));
		mat2d.set_param("in_tex", 0);
		mat2d.set_param("color", Vec3(0.9, 0.5, 0.7));

		glcheck();
	}
	
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
			glBindVertexArray(vao_text);
			glDrawElements(GL_TRIANGLES, cast(int)mesh.triangles.length*3, GL_UNSIGNED_INT, cast(GLvoid*) 0);
			glBindVertexArray(0);
		}
		glcheck();

		ww.end_frame();
	}
	return 0;
	//*/
}