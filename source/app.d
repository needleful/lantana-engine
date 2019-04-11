// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

import std.stdio;

import core.types;
import game.input;
import game.window;
import graphics.buffer;

int main()
{
	float usec_delta = 1;

	Window ww = Window(-720, 512, "Lantana");

	Vec3[3] verts = [
		Vec3(-1, -1, 0),
		Vec3( 1, -1, 0),
		Vec3( 0,  1, 0),
	];

	VertexBuffer buf = ww.make_buffer(verts);

	assert(verts.sizeof == buf.vertices.length*Vec3.sizeof);

	VertexBuffer[1] buffers = [buf];

	while(ww.should_run)
	{
		ww.poll_events();
		ww.begin_frame();

		ww.render_buffers(buffers);

		ww.end_frame();
	}

	return 0;
}
