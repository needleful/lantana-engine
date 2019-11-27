// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

import std.math;
import std.stdio;

import lanlib.formats.gltf2;
import lanlib.math.projection;
import lanlib.math.transform;
import lanlib.sys.memory;
import lanlib.sys.sdl;

import gl3n.linalg;

import logic.grid;
import logic.input;
import logic.player;

import render.camera;
import render.Material;
import render.mesh;

import ui.text;

enum MAX_MEMORY = 1024*1024;

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

	TextAtlas text = new TextAtlas("data/fonts/averia/Averia-Light.ttf", 28, 256, 256);
	text.blitgrid();

	auto debug_msg = text.add_text("Hello, world!", ivec2(20, 20), vec3(1, 0.2, 0.2));

	ILanAllocator sysmem = new SysMemManager();
	auto mm = new LanRegion(MAX_MEMORY, sysmem);

	AnimatedMeshSystem anim_mesh = AnimatedMeshSystem(1);
	assert(anim_mesh.mat.can_render());

	auto loaded = glb_load!true("data/test/meshes/funny-cube.glb", mm);

	assert(loaded.accessors.length == 1);

	auto test_mesh = anim_mesh.build_mesh(loaded.accessors[0], loaded.data);

	auto meshes = mm.make_list!(Instance!AnimatedMesh)(1000);

	meshes[0].transform = Transform(0.5, vec3(0,0,2));
	meshes[0].mesh = test_mesh;

	Transform* tr = &meshes[0].transform;

	// Putting cubes
	for(uint i = 1; i < meshes.length; i++)
	{
		meshes[i].transform = Transform(0.5, vec3((i/100)*2, 0.2, 2+(i % 100)*2));
		meshes[i].transform.rotate_degrees(90,0,0);
		meshes[i].mesh = test_mesh;
	}

	Camera* cam = mm.create!Camera(vec3(0,0,0), 720.0/512, 60);

	uint frame = 0;

	Grid* grid = mm.create!Grid(GridPos(-5, 0, -5), GridPos(5,0,5), 1, vec3(5, 7, 5));
	Player* player = mm.create!Player(grid, GridPos(0,0,0));

	int[2] wsize = ww.get_dimensions();

	writeln("Beginning game loop");

	stdout.flush();

	while(!(ww.state & WindowState.CLOSED))
	{
		float delta = ww.delta_ms()/1000.0;
	
		ww.poll_events(ii);

		if(ww.state & WindowState.RESIZED)
		{
			wsize = ww.get_dimensions();
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
			cam.rot.x += ii.mouse_movement.x*delta*60;
			float next_rot = cam.rot.y + ii.mouse_movement.y;
			if(abs(next_rot) < 90){
				cam.rot.y = next_rot;
			}

			player.frame(ii, delta);

			tr._position = player.getPos();
			tr.rotate_degrees(0, 40*delta, 0);
			tr.compute_matrix();
		}
		ww.begin_frame();
		
		anim_mesh.render(cam.vp(), meshes);

		text.render(wsize);

		ww.end_frame();
		frame ++;
	}

	writeln("Exiting game");
	return 0;
}