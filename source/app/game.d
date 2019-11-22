// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

import std.math;
import std.stdio;

import lanlib.formats.gltf2;
import lanlib.math.matrix;
import lanlib.math.projection;
import lanlib.math.vector;
import lanlib.math.transform;
import lanlib.sys.memory;
import lanlib.sys.sdl;

import logic.grid;
import logic.input;
import logic.player;

import render.camera;
import render.material;
import render.mesh;

import ui.text;

enum MAX_MEMORY = 1024*1024;

enum cam_speed = 8;

bool paused;

int main()
{
	debug {
		writeln("Running Axe Manor in debug mode!");
	}
	SDLWindow ww = SDLWindow(720, 512, "Axe Manor");
	auto mm = new LanRegion(MAX_MEMORY, new SysMemManager());

	Input input = Input();
	TextAtlas text = new TextAtlas("data/fonts/averia/Averia-Light.ttf", 28, 256, 256);
	StaticMeshSystem smesh = StaticMeshSystem(8);

	GLBLoadResults level_loaded = glb_load("data/test/meshes/level.glb", mm);
	GLBLoadResults player_loaded = glb_load("data/meshes/player.glb", mm);

	auto level_mesh = smesh.build_mesh(level_loaded.accessors[0], level_loaded.data);
	auto player_meshes = smesh.build_meshes(player_loaded);

	auto cam = mm.create!Camera(Vec3(0,0,0), 720.0/512, 60);

	uint frame = 0;

	auto grid = mm.create!Grid(GridPos(-5, 0, -5), GridPos(5,0,5), 1, Vec3(5, 7, 5));
	auto player = Player(grid, GridPos(0,0,0));

	int[2] wsize = ww.get_dimensions();

	writeln("Beginning game loop");

	stdout.flush();

	while(!(ww.state & WindowState.CLOSED))
	{
		float delta = ww.delta_ms()/1000.0;
	
		ww.poll_events(input);

		if(ww.state & WindowState.RESIZED)
		{
			wsize = ww.get_dimensions();
			cam.set_projection(
				Projection(cast(float)wsize[0]/wsize[1], 60, DEFAULT_NEAR_PLANE, DEFAULT_FAR_PLANE)
			);
		}

		if(input.is_just_pressed(Input.Action.PAUSE))
		{
			paused = !paused;
			ww.grab_mouse(!paused);
		}

		if(!paused)
		{
			cam.rot.x += input.mouse_movement.x*delta*60;
			float next_rot = cam.rot.y + input.mouse_movement.y;
			if(abs(next_rot) < 90){
				cam.rot.y = next_rot;
			}

			player.frame(input, delta);

			tr._position = player.getPos();
			tr.rotate_degrees(0, 40*delta, 0);
			tr.compute_matrix();
		}
		ww.begin_frame();
		
		smesh.render(cam.vp(), meshes);

		text.render(wsize);

		ww.end_frame();
		frame ++;
	}

	writeln("Exiting game");
	return 0;
}