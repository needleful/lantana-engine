// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

import std.math;
import std.stdio;

import lanlib.math.matrix;
import lanlib.math.projection;
import lanlib.math.vector;
import lanlib.math.transform;

import lanlib.sys.input;
import lanlib.sys.memory;
import lanlib.sys.sdl;

import render.camera;
import render.material;
import render.mesh;

enum MAX_MEMORY = 1024*1024*20;

enum cam_speed = 8;

bool paused;

int main()
{
	debug {
		writeln("Running Lantana in debug mode!");
	}
	SDLWindow ww = SDLWindow(720, 512, "Lantana");
	Input ii = Input();
	ii.clear();
	MemoryStack mm = MemoryStack(MAX_MEMORY);

	Material test_mat = load_material("data/shaders/test.vert", "data/shaders/test.frag");

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
	elems[0] = Tri(0, 6, 2);
	elems[1] = Tri(0, 4, 6);

	elems[2] = Tri(0, 2, 1);
	elems[3] = Tri(1, 2, 3);

	elems[4] = Tri(4, 5, 7);
	elems[5] = Tri(4, 7, 6);

	elems[6] = Tri(5, 3, 7);
	elems[7] = Tri(5, 1, 3);

	elems[8] = Tri(2, 7, 3);
	elems[9] = Tri(2, 6, 7);

	elems[10] = Tri(0, 1, 5);
	elems[11] = Tri(0, 5, 4);

	Mesh test_mesh = Mesh(verts, elems);
	auto group = new MultiMesh(&test_mesh, &test_mat);

	Transform[] transforms = mm.reserve_list!Transform(10_000);

	transforms[0] = Transform(0.5, Vec3(0,0,2));

	for(uint i = 1; i < transforms.length; i++)
	{
		transforms[i] = Transform(0.5, Vec3((i/100)*2, 0, 2+(i % 100)*2));
	}

	Camera* cam = mm.create!Camera(Vec3(0,0,0), 720.0/512, 60);
	
	UniformId transformId = group.material.get_param_id("transform");
	UniformId projId = group.material.get_param_id("projection");

	group.material.set_param("color", Vec3(0.2, 0.4, 1));

	Vec2 input = Vec2(0,0);
	uint frame = 0;

	Mat4 ident = Mat4_Identity;
	debug
	{
		printf("Starting game loop.\n");
	}
	while(!(ww.state & WindowState.CLOSED))
	{
		auto d = ww.delta_ms;
		if(frame % 300 == 0)
		{
			printf("frame: %dms  ", d);
		}
		ww.poll_events(ii);

		if(ww.state & WindowState.RESIZED)
		{
			int[2] wsize = ww.get_dimensions();
			cam.set_projection(
				Projection(cast(float)wsize[0]/wsize[1], 60, DEFAULT_NEAR_PLANE, DEFAULT_FAR_PLANE)
			);
		}

		if(ii.is_just_pressed(Input.Action.PAUSE))
		{
			paused = !paused;
			ww.grab_mouse(!paused);
		}

		if(!paused)
		{
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

			cam.rot.x += ii.mouse_movement.x;
			float next_rot = cam.rot.y + ii.mouse_movement.y;
			if(abs(next_rot) < 90){
				cam.rot.y = next_rot;
			}

			cam.pos += cam.right()*input.x*0.016*cam_speed;
			cam.pos += cam.forward()*input.y*0.016*cam_speed;

			//transform.scale(0.5+sin(ww.time/2000.0)*0.2);
			transforms[0].rotate_degrees(0, 0.5, 0);

			if(ii.is_pressed(Input.Action.JUMP))
			{
				//printf("Camera Angle: %f %f\n", cam.rot.x, cam.rot.y);
				cam.pos += cam.up()*0.016*cam_speed;
			}
			
			group.material.set_param(projId, cam.vp);
		}

		auto start = ww.delta_ms;
		ww.begin_frame();

		group.process(transforms);

		ww.end_frame();
		auto end = ww.delta_ms;

		if(frame % 300 == 0)
		{
			printf("render: %dms\n", end-start);
		}
		frame ++;
	}

	return 0;
}