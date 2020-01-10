// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

import std.format;
import std.math;
import std.stdio;

import lanlib.formats.gltf2;
import lanlib.math.projection;
import lanlib.math.transform;
import lanlib.types;
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
import render.textures;
import scene;
import test.scenes;

import ui;

enum MAX_MEMORY = 1024*1024*16;

enum cam_speed = 8;

int main()
{
	debug writeln("Running Axe Manor in debug mode!");
	SDLWindow ww = SDLWindow(720, 512, "Axe Manor");
	
	auto mm = new LanRegion(MAX_MEMORY, new SysMemManager());
	Input input = Input();

	StaticMeshSystem smesh = StaticMeshSystem(3);
	AnimatedMeshSystem anmesh = AnimatedMeshSystem(2);

	UIRenderer ui = new UIRenderer(ww.getSize(), mm);

	FontId debugFont = ui.loadFont("data/fonts/averia/Averia-Regular.ttf", 20);

	string debugText = ": %6.3f\n: %6.3f\n: %6.3f";
	TextBox frameTime = new TextBox(ui, debugFont, debugText, true);

	ui.setRootWidget(new HodgePodge([
		new Anchor(
			new HBox([
				new TextBox(ui, debugFont, "Frame Time\nMax\nAverage"), 
				frameTime
			], 5),
			vec2(0.99, 0.99),
			vec2(1, 1)
		)
	]));

	// Testing SceneLoader format
	StaticMeshInstance[] staticMeshes;
	AnimatedMeshInstance[] animMeshes;
	LightInfo worldLight;
	Grid grid;
	Player player;
	ushort playerMesh, blockMesh;
	{
		SceneLoader loader = testScene();
		StaticMesh*[] smeshes;
		AnimatedMesh*[] ameshes;
		smeshes.reserve(loader.files_staticMesh.length);
		ameshes.reserve(loader.files_animMesh.length);

		foreach(meshFile; loader.files_staticMesh)
		{
			smeshes ~= smesh.load_mesh(meshFile, mm);
		}
		foreach(meshFile; loader.files_animMesh)
		{
			ameshes ~= anmesh.load_mesh(meshFile, mm);
		}

		staticMeshes = mm.make_list!StaticMeshInstance(loader.meshInstances.length);
		animMeshes = mm.make_list!AnimatedMeshInstance(loader.animatedInstances.length);

		foreach(i; 0..loader.meshInstances.length)
		{
			auto m = &loader.meshInstances[i];
			staticMeshes[i].mesh = smeshes[m.id];
			staticMeshes[i].transform = m.transform;
		}

		foreach(i; 0..loader.animatedInstances.length)
		{
			auto m = &loader.animatedInstances[i];
			animMeshes[i] = AnimatedMeshInstance(ameshes[m.id], m.transform, mm);
			if(m.animation != "")
			{
				animMeshes[i].play_animation(m.animation, m.loop);
			}
		}

		grid = loader.grid;
		player = loader.player;
		player.grid = &grid;
		playerMesh = loader.playerMeshInstance;
		blockMesh = loader.blockInstancesOffset;

		worldLight = LightInfo(loader.lights.file_palette, mm);
		worldLight.direction = loader.lights.direction;
		worldLight.bias = loader.lights.bias;
		worldLight.areaCeiling = loader.lights.areaCeiling;
		worldLight.areaSpan = loader.lights.areaSpan;
	}

	auto cam = mm.create!Camera(vec3(-3, -9, -3), 720.0/512, 60);

	uint frame = 0;
	int[2] wsize = ww.get_dimensions();

	debug writeln("Beginning game loop");
	stdout.flush();

	float maxDelta_ms = -1;
	float runningMaxDelta_ms = -1;
	float accumDelta_ms = 0;
	float runningFrame = 0;
	bool paused;

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
			if(abs(next_rot) < 90)
			{
				cam.rot.y = next_rot;
			}
			player.update(input, delta);

			staticMeshes[playerMesh].transform._position = grid.getRealPosition(player.pos, player.pos_target);
			staticMeshes[playerMesh].transform._rotation.y = player.dir.getRealRotation();
			staticMeshes[playerMesh].transform.compute_matrix();

			foreach(i; 0..grid.blocks.length)
			{
				auto s = i+blockMesh;
				staticMeshes[s].transform._position = grid.getRealPosition(grid.blocks[i].position, grid.blocks[i].pos_target);
				staticMeshes[s].transform.compute_matrix();
			}

			anmesh.update(delta, animMeshes);
		}
		ui.update(delta);

		ww.begin_frame();
		mat4 vp = cam.vp();
		anmesh.render(vp, worldLight, animMeshes);
		smesh.render(vp, worldLight, staticMeshes);
		ui.render();

		ww.end_frame();
		frame ++;
	}
	debug writeln("Game closing");
	return 0;
}