// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

import std.format;
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
import render.lights;
import render.material;
import render.mesh;

import ui;

enum MAX_MEMORY = 1024*1024*5;

enum cam_speed = 8;

bool paused;

int main()
{
	debug writeln("Running Axe Manor in debug mode!");
	SDLWindow ww = SDLWindow(720, 512, "Axe Manor");
	
	auto mm = new LanRegion(MAX_MEMORY, new SysMemManager());
	Input input = Input();

	StaticMeshSystem smesh = StaticMeshSystem(3);
	AnimatedMeshSystem anmesh = AnimatedMeshSystem(2);

	GLBStaticLoadResults level_loaded = glb_load("data/test/meshes/funny-cube.glb", mm);
	GLBAnimatedLoadResults player_loaded = glb_load!true("data/test/meshes/anim_test.glb", mm);

	UIRenderer ui = new UIRenderer(ww.getSize());

	SpriteId needlefulPNG = ui.loadSprite("data/test/needleful.png");
	SpriteId upclickSprite = ui.loadSprite("data/test/ui_sprites/upclick.png");

	FontId testFont = ui.loadFont("data/fonts/averia/Averia-Regular.ttf");

	string debugState = "Frame Time: %4.2f ms\nMax       : %8.4f ms\nAverage   : %8.4f ms";
	TextBox frameTime = new TextBox(ui, testFont, debugState, true);

	ui.setRootWidget(new HodgePodge([
		// various tests for Anchor, ImageBox, and TextBox
		new Anchor(
			new TextBox(ui, testFont, "Hello"),
			vec2(0.5,0.6),
			vec2(0.5,0)
		),
		new Anchor(
			new ImageBox(ui, upclickSprite),
			vec2(1,0), vec2(1,0)
		),
		new Anchor(
			new ImageBox(ui, needlefulPNG),
			vec2(0.027, 0.048),
			vec2(0, 0)
		),
		new Anchor(
			frameTime,
			vec2(0.99, 0.99),
			vec2(1, 1)
		)
	]));

	auto level_mesh = smesh.build_mesh(level_loaded.accessors[0], level_loaded.data);
	auto player_mesh = anmesh.build_mesh(player_loaded.accessors[0], player_loaded);

	auto cam = mm.create!Camera(vec3(0,0,0), 720.0/512, 60);
	auto grid = mm.create!Grid(GridPos(-5, 0, -5), GridPos(5,0,5), 1, vec3(5, 7, 5));
	auto player = Player(grid, GridPos(0,0,0));

	auto anim_meshes = mm.make_list!AnimatedMeshInstance(1);

	auto pmesh = &anim_meshes[0];

	pmesh.transform = Transform(0.5, vec3(0,0,0));
	pmesh.mesh = player_mesh;
	pmesh.boneMatrices = mm.make_list!mat4(player_mesh.bones.length);
	pmesh.bones = mm.make_list!GLBNode(player_mesh.bones.length);
	pmesh.bones[0..$] = player_mesh.bones[0..$];
	pmesh.is_playing = false;
	pmesh.play_animation("TestAnim", true);

	auto level_meshes = mm.make_list!StaticMeshInstance(2);
	level_meshes[0].mesh = level_mesh;
	level_meshes[0].transform = Transform(4, vec3(5,10,5));
	level_meshes[1].mesh = smesh.build_mesh(player_loaded.accessors[0].mesh(), player_loaded.data);
	level_meshes[1].transform = Transform(2, vec3(2, 12, 2));

	uint frame = 0;
	int[2] wsize = ww.get_dimensions();

	writeln("Beginning game loop");
	stdout.flush();

	LightInfo worldLight;
	worldLight.color = vec3(.9, .9, 0.7);
	worldLight.ambiance = vec3(0.15, 0.1, 0.4);
	worldLight.direction = vec3(0.2, -1, 0.1);
	worldLight.bias = 0.2;

	float maxDelta_ms = -1;
	float runningMaxDelta_ms = -1;
	float accumDelta_ms = 0;
	float runningFrame = 0;

	while(!ww.state[WindowState.CLOSED])
	{
		float delta_ms = ww.delta_ms();
		float delta = delta_ms/1000.0;
		debug
		{	
			runningMaxDelta_ms = delta_ms > runningMaxDelta_ms ? delta_ms : runningMaxDelta_ms;
			
			if(frame % 1024 == 0)
			{
				maxDelta_ms = runningMaxDelta_ms;
				runningMaxDelta_ms = -1;
				accumDelta_ms = 0;
				runningFrame = 1;
			}
			accumDelta_ms += delta_ms;
			frameTime.setText(format(debugState, delta_ms, maxDelta_ms, accumDelta_ms/runningFrame));
			runningFrame ++;
		}
	
		ww.poll_events(input);

		if(ww.state[WindowState.RESIZED])
		{
			wsize = ww.get_dimensions();
			cam.set_projection(
				Projection(cast(float)wsize[0]/wsize[1], 60, DEFAULT_NEAR_PLANE, DEFAULT_FAR_PLANE)
			);
			ui.setSize(ww.getSize());
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
		ui.update(delta);

		ww.begin_frame();
		mat4 vp = cam.vp();
		smesh.render(vp, worldLight, level_meshes);
		anmesh.render(vp, worldLight, anim_meshes);
		ui.render();

		ww.end_frame();
		frame ++;
	}
	return 0;
}