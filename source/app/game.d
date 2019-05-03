// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

import std.math;
import std.stdio;

import lanlib.math.matrix;
import lanlib.math.vector;
import lanlib.math.transform;

import lanlib.sys.input;
import lanlib.sys.memory;
import lanlib.sys.sdl;

import render.camera;
import render.material;
import render.mesh;

enum MAX_MEMORY = 1024*1024*8;

enum cam_speed = 8;

int main()
{
	debug {
		writeln("Running Lantana in debug mode!");
	}
	SDLWindow ww = SDLWindow(720, 512, "Lantana");
	Input ii = Input();
	ii.clear();
	MemoryStack mm = MemoryStack(MAX_MEMORY);

	MeshGroup* group = mm.create!MeshGroup();
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

	Mesh* test_mesh = mm.create!Mesh(verts, elems);
	MeshInstance[] meshes = mm.reserve_list!MeshInstance(10_001);

	meshes[0].mesh = test_mesh;
	meshes[0].transform = Transform(0.5, Vec3(0,0,2));

	for(uint i = 1; i < meshes.length; i++)
	{
		meshes[i].mesh = test_mesh;
		meshes[i].transform = Transform(0.5, Vec3((i/100)*2, 0.75, (i % 100)*2));
	}

	Camera* cam = mm.create!Camera(Vec3(0,0,0), 720.0/512, 60);
	
	UniformId transformId = group.material.get_param_id("transform");
	UniformId projId = group.material.get_param_id("projection");

	group.material.set_param(transformId, meshes[0].transform.matrix);
	group.material.set_param("color", Vec3(0.2, 0.4, 1));

	Vec2 input = Vec2(0,0);

	Mat4 ident = Mat4_Identity;
	while(ww.should_run)
	{
		ww.poll_events(ii);

		input.x = 0.0f;
		input.y = 0.0f;

		if(ii.is_pressed(Input.Action.LEFT))
		{
			input.x -= 1;
		}
		if(ii.is_pressed(Input.Action.RIGHT))
		{
			input.x += 1;
		}
		if(ii.is_pressed(Input.Action.UP))
		{
			input.y += 1;
		}
		if(ii.is_pressed(Input.Action.DOWN))
		{
			input.y -= 1;
		}

		cam.rot += ii.mouse_movement;

		cam.pos += cam.right()*input.x*0.016*cam_speed;
		cam.pos += cam.forward()*input.y*0.016*cam_speed;

		if(ii.is_just_pressed(Input.Action.PAUSE))
		{
			cam.rot = Vec2(0,0);
			cam.pos = Vec3(0,0,0);
		}

		//transform.scale(0.5+sin(ww.time/2000.0)*0.2);
		meshes[0].transform.rotate_degrees(0, 0.5, 0.5);

		if(ii.is_pressed(Input.Action.JUMP))
		{
			printf("Camera Angle: %f %f\n", cam.rot.x, cam.rot.y);
		}
		
		group.material.set_param(group.transform, meshes[0].transform.matrix);
		group.material.set_param(projId, cam.vp);

		ww.begin_frame();

		group.render(meshes);

		ww.end_frame();
	}

	return 0;
}
