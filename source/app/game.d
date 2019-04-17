// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

import std.math;
import std.stdio;

import lanlib.math.vector;
import lanlib.math.transform;
import lanlib.sys.input;
import lanlib.sys.memory;
import lanlib.sys.window;
import components.render.mesh;
import components.render.material;
import systems.render.mesh;

int main()
{
	debug {
		writeln("Running Lantana in debug mode!");
	}
	Window ww = Window(720, 512, "Lantana");
	Input ii = Input();
	MemoryStack mm = MemoryStack(2048);

	MeshGroup group = MeshGroup();
	group.load_material("data/shaders/test.vert", "data/shaders/test.frag");

	Vec3[] verts = mm.reserve_list!Vec3(8);
	verts[0] = Vec3(-1, -1, -1);
	verts[1] = Vec3(-1, -1,  1);
	verts[2] = Vec3(-1,  1, -1);
	verts[3] = Vec3(-1,  1,  1);
	verts[4] = Vec3( 1, -1, -1);
	verts[5] = Vec3( 1, -1,  1);
	verts[6] = Vec3( 1,  1, -1);
	verts[7] = Vec3( 1,  1,  1);

	Tri[] elems = mm.reserve_list!Tri(12);
	elems[0] = Tri(0, 2, 6);
	elems[1] = Tri(0, 6, 4);

	elems[2] = Tri(0, 1, 2);
	elems[3] = Tri(1, 3, 2);

	elems[4] = Tri(4, 7, 5);
	elems[5] = Tri(4, 6, 7);

	elems[6] = Tri(5, 7, 3);
	elems[7] = Tri(5, 3, 1);

	elems[8] = Tri(2, 3, 7);
	elems[9] = Tri(2, 7, 6);

	elems[10] = Tri(0, 5, 1);
	elems[11] = Tri(0, 4, 5);

	Mesh test_mesh = Mesh(verts, elems);
	group.meshes = [test_mesh];

	auto transform = mm.create!Transform(0.5, Vec3(0,0,0));
	
	UniformId transformId = group.material.get_param_id("transform");
	group.material.set_param(transformId, transform.matrix);
	group.material.set_param("color", Vec3(0.2, 0.4, 1));

	Vec3 input = Vec3(0,0,0);

	while(ww.should_run)
	{
		ww.poll_events(ii);

		input.x = 0.0f;
		input.y = 0.0f;

		if(ii.is_pressed(Input.Action.LEFT))
		{
			input.x = input.x - 1;
		}
		if(ii.is_pressed(Input.Action.RIGHT))
		{
			input.x = input.x + 1;
		}
		if(ii.is_pressed(Input.Action.UP))
		{
			input.y = input.y + 1;
		}
		if(ii.is_pressed(Input.Action.DOWN))
		{
			input.y = input.y - 1;
		}

		transform.translate(input*0.016);
		//transform.scale(0.5+sin(ww.time/2000.0)*0.2);
		transform.rotate_degrees_axis(0.5, Vec3(1,1,1));
		
		group.material.set_param(transformId, transform.matrix);

		ww.begin_frame();

		group.render();

		ww.end_frame();
	}

	return 0;
}
