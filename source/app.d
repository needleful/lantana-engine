// Part of the Daisy Engine
// developed by needleful
// Licensed under GPL v3.0

import std.stdio;

import core.types;
import graphics.context;
import graphics.buffer;
import input;

int main()
{
	float usec_delta = 1;

	GContext gg;
	if(!gg.init(720, 512, "Daisy Engine"))
	{
		printf("Failed to initialize Daisy.\n");
		return 1;
	}

	Vec3[1] verts = [Vec3(0,0,0)];

	printf("Made vertices");
	VertexBuffer buf = gg.make_buffer(verts);
	printf("Made buffer");

	while(gg.should_run)
	{
		gg.begin_frame();
		gg.poll_events();

		gg.end_frame();
	}

	scope(exit)
	{
		gg.cleanup();
	}

	return 0;
}
