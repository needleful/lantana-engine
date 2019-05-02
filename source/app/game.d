// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

import std.math;
import std.stdio;

import lanlib.render.material;
import lanlib.render.mesh;

import lanlib.types.matrix;
import lanlib.types.vector;

import lanlib.sys.input;
import lanlib.sys.sdl;

import derelict.sdl2.image;

int main()
{
	debug {
		writeln("Running Lantana2D in debug mode!");
	}
	SDLWindow ww = SDLWindow(720, 512, "Lantana2D");
	Input ii = Input();

	DerelictSDL2Image.load();

	Vec2[] verts = [
		Vec2(0, 0),
		Vec2(0, 1),
		Vec2(1, 0),
		Vec2(1, 1),
	];

	Vec2[] UVs = verts;

	Tri[] tris = [
		Tri(0, 1, 3),
		Tri(0, 3, 2)
	];

	Mesh2D mesh = Mesh2D(verts, UVs, tris);

	Material mat = load_material("data/shaders/test.vert", "data/shaders/test.frag");
	mat.set_param("uv_offset", Vec2(0,0));
	mat.set_param("translate", Vec2(0,0));
	mat.set_param("scale", Vec2(1,1));
	mat.set_param("cam_position", Vec2(0,0));
	mat.set_param("cam_scale", Vec2(1,1));
	
	while(ww.should_run)
	{
		ww.poll_events(ii);

		ww.begin_frame();

		

		ww.end_frame();
	}

	return 0;
}
