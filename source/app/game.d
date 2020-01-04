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

	UIRenderer ui = new UIRenderer(ww.getSize());

	SpriteId needlefulPNG = ui.loadSprite("data/test/needleful.png");
	SpriteId upclickSprite = ui.loadSprite("data/test/ui_sprites/upclick.png");

	FontId debugFont = ui.loadFont("data/fonts/averia/Averia-Regular.ttf", 20);
	FontId titleFont = ui.loadFont("data/fonts/averia/Averia-Light.ttf", 40);

	string debugText = ": %6.3f\n: %6.3f\n: %6.3f";
	TextBox frameTime = new TextBox(ui, debugFont, debugText, true);

	ui.setRootWidget(new HodgePodge([
		// various tests for Anchor, ImageBox, and TextBox
		new Anchor(
			new TextBox(ui, titleFont, "Lantana Engine"),
			vec2(0.05, 0.99),
			vec2(0, 1)
		),
		new Anchor(
			new HBox([
				new TextBox(ui, debugFont, "Frame Time\nMax\nAverage"), 
				frameTime
			], 5),
			vec2(0.99, 0.99),
			vec2(1, 1)
		)
	]));

	// Meshes
	auto level_mesh = smesh.load_mesh("data/test/meshes/funny-cube.glb", mm);
	auto player_mesh = smesh.load_mesh("data/test/meshes/kitty-test.glb", mm);
	auto anim_mesh = anmesh.load_mesh("data/test/meshes/anim_test.glb", mm);
	auto anim_meshes = mm.make_list!AnimatedMeshInstance(1);

	auto animTest = &anim_meshes[0];

	animTest.transform = Transform(1, vec3(-6,0,6));
	animTest.mesh = anim_mesh;
	animTest.boneMatrices = mm.make_list!mat4(anim_mesh.bones.length);
	animTest.bones = mm.make_list!GLBNode(anim_mesh.bones.length);
	animTest.bones[0..$] = anim_mesh.bones[0..$];
	animTest.is_playing = false;
	animTest.play_animation("TestAnim", true);

	auto static_meshes = mm.make_list!StaticMeshInstance(4);
	// Player
	static_meshes[0].mesh = player_mesh;
	static_meshes[0].transform = Transform(1, vec3(0));
	auto pmesh = &static_meshes[0];
	// Static geometry
	static_meshes[1].mesh = level_mesh;
	static_meshes[1].transform = Transform(4, vec3(0, 5, 0));

	// BLocks
	static_meshes[2].mesh = level_mesh;
	static_meshes[2].transform = Transform(1, vec3(0));
	static_meshes[3].mesh = level_mesh;
	static_meshes[3].transform = Transform(1, vec3(0));


	auto cam = mm.create!Camera(vec3(-3, -9, -3), 720.0/512, 75);
	auto grid = mm.create!Grid(GridPos(-5, 0, -5), GridPos(5,0,5), vec3(0,0,0));
	auto player = Player(grid, GridPos(0,0,0));

	grid.blocks = mm.make_list!GridBlock(2);
	grid.blocks[0].setPosition(2, 0, 2);
	grid.blocks[1].setPosition(3, 0, 3);

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
			
			if(frame % 512 == 0)
			{
				maxDelta_ms = runningMaxDelta_ms;
				runningMaxDelta_ms = -1;
				accumDelta_ms = 0;
				runningFrame = 1;
			}
			accumDelta_ms += delta_ms;
			frameTime.setText(format(debugText, delta_ms, maxDelta_ms, accumDelta_ms/runningFrame));
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
			player.update(input, delta);
			pmesh.transform._position = player.realPosition();
			pmesh.transform._rotation.y = player.realRotation();
			pmesh.transform.compute_matrix();

			static_meshes[2].transform._position = grid.getRealPosition(grid.blocks[0].position, grid.blocks[0].pos_target);
			static_meshes[2].transform.compute_matrix();
			static_meshes[3].transform._position = grid.getRealPosition(grid.blocks[1].position, grid.blocks[1].pos_target);
			static_meshes[3].transform.compute_matrix();

			anmesh.update(delta, anim_meshes);
		}
		ui.update(delta);

		ww.begin_frame();
		mat4 vp = cam.vp();
		smesh.render(vp, worldLight, static_meshes);
		anmesh.render(vp, worldLight, anim_meshes);
		ui.render();

		ww.end_frame();
		frame ++;
	}
	return 0;
}