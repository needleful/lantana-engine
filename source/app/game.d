// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

import std.math;
import std.stdio;

import lanlib.formats.gltf2;
import lanlib.math.projection;
import lanlib.math.transform;
import lanlib.util.memory;
import lanlib.util.sdl;

import gl3n.linalg;

import logic.grid;
import logic.input;
import logic.player;

import render.camera;
import render.material;
import render.mesh;

import ui.layout;
import ui.text;

enum MAX_MEMORY = 1024*1024*5;

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

	StaticMeshSystem smesh = StaticMeshSystem(3);
	AnimatedMeshSystem anmesh = AnimatedMeshSystem(2);

	GLBStaticLoadResults level_loaded = glb_load("data/test/meshes/funny-cube.glb", mm);
	GLBAnimatedLoadResults player_loaded = glb_load!true("data/test/meshes/anim_test.glb", mm);

	auto debug_msg = text.add_text("Hello, world!", ivec2(20, 20), vec3(1, 0.2, 0.2));

	auto level_mesh = smesh.build_mesh(level_loaded.accessors[0], level_loaded.data);
	auto player_mesh = anmesh.build_mesh(player_loaded.accessors[0], player_loaded);

	auto cam = mm.create!Camera(vec3(0,0,0), 720.0/512, 60);
	auto grid = mm.create!Grid(GridPos(-5, 0, -5), GridPos(5,0,5), 1, vec3(5, 7, 5));
	auto player = Player(grid, GridPos(0,0,0));

	auto test_mesh = anmesh.build_mesh(player_loaded.accessors[0], player_loaded);
	auto anim_meshes = mm.make_list!AnimatedMeshInstance(1);

	auto pmesh = &anim_meshes[0];

	pmesh.transform = Transform(0.5, vec3(0,0,2));
	pmesh.mesh = test_mesh;
	pmesh.boneMatrices = mm.make_list!mat4(test_mesh.bones.length);
	pmesh.bones = mm.make_list!GLBNode(test_mesh.bones.length);
	pmesh.bones[0..$] = test_mesh.bones[0..$];
	pmesh.is_playing = false;
	pmesh.play_animation("TestAnim", true);

	auto level_meshes = mm.make_list!StaticMeshInstance(1);

	float delta_time = 0;
	import std.datetime.stopwatch: StopWatch, AutoStart;
	auto sw = StopWatch(AutoStart.yes);
	uint frame = 0;
	int[2] wsize = ww.get_dimensions();

	writeln("Beginning game loop");
	stdout.flush();

	while(!ww.state[WindowState.CLOSED])
	{
		float delta = ww.delta_ms()/1000.0;
		delta_time += delta;
	
		ww.poll_events(input);

		if(ww.state[WindowState.RESIZED])
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
			pmesh.transform._position = player.getPos();
			pmesh.transform.compute_matrix();
			anmesh.update(delta, anim_meshes);
		}

		ww.begin_frame();
		smesh.render(cam.vp(), level_meshes);
		anmesh.render(cam.vp(), anim_meshes);

		text.render(wsize);

		ww.end_frame();
		frame ++;
	}
	sw.stop();
	writeln("Delta time: ", delta_time, ", Actual Time: ", sw.peek.total!"msecs"()/1000.0);
	writeln("Exiting game");
	return 0;
}