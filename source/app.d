// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

import std.math;
import std.stdio;

import core.types;
import game.input;
import game.window;
import graphics.buffer;
import graphics.material;

int main()
{
	debug {
		writeln("Running Lantana in debug mode!");
	}

	Window ww = Window(720, 512, "Lantana");
	Vec3[3] verts = [
		Vec3(-1, -1, 0),
		Vec3( 1, -1, 0),
		Vec3( 0,  1, 0),
	];

	auto buf = VertexBuffer(verts);

	assert(verts.sizeof == buf.bytesize);

	VertexBuffer[1] buffers = [buf];

	auto test_mat = Material("data/shaders/test.vert", "data/shaders/test.frag");

	test_mat.set_param("color", Vec3(0.2, 0.4, 1));
	test_mat.set_param("scale", 0.2);

	while(ww.should_run)
	{
		ww.poll_events();

		test_mat.set_param("scale", 1+sin(ww.time/2000.0)*0.2);
		ww.begin_frame();

		ww.render_buffers(test_mat, buffers);

		ww.end_frame();
	}

	return 0;
}
