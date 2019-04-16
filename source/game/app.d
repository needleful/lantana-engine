// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

import std.math;
import std.stdio;

import math.vector;
import math.transform;
import sys.input;
import sys.window;
import graphics.buffer;
import graphics.material;

int main()
{
	debug {
		writeln("Running Lantana in debug mode!");
	}

	Window ww = Window(720, 512, "Lantana");
	Input ii = Input();

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

	auto transform = Transform(0.5, Vec3(0,0,0));

	test_mat.set_param("transform", transform.matrix);

	UniformId transformId = test_mat.get_param_id("transform");

	Vec3 direction = Vec3(0,0,0);

	while(ww.should_run)
	{
		ww.poll_events(ii);

		direction.x = 0.0f;
		direction.y = 0.0f;

		if(ii.is_pressed(Input.Action.LEFT))
		{
			direction.x = direction.x - 1;
		}
		if(ii.is_pressed(Input.Action.RIGHT))
		{
			direction.x = direction.x + 1;
		}
		if(ii.is_pressed(Input.Action.UP))
		{
			direction.y = direction.y + 1;
		}
		if(ii.is_pressed(Input.Action.DOWN))
		{
			direction.y = direction.y - 1;
		}

		transform.translate(direction*0.016);
		//transform.scale(0.5+sin(ww.time/2000.0)*0.2);
		transform.rotate_radians(0.01);
		
		test_mat.set_param(transformId, transform.matrix);

		ww.begin_frame();

		ww.render_buffers(test_mat, buffers);

		ww.end_frame();
	}

	return 0;
}
