// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module test.scenes;

import gl3n.linalg: vec3;

import lanlib.math.transform;
import lanlib.util.memory;
import logic.grid;
import logic.player;
import logic.scenes;

import render.camera;

SceneLoader testScene()
{
	SceneLoader s;

	s.lights = LightLoader(
		vec3(-0.2, -1, 0.1), // Direction
		0.3, // Bias
		-5,  // Area Ceiling
		12,  // Area Span
		"data/palettes/test.png"
	);

	s.files_staticMesh = [
		"data/test/meshes/funny-cube.glb",
		"data/test/meshes/tree_temperate01.glb",
	];

	s.files_animMesh = [
		"data/test/meshes/kitty-test.glb",
		"data/test/meshes/anim_test.glb",
	];

	s.meshInstances = [
		MeshInstanceLoader(0, Transform(4, vec3(0, 5, 0))),
		MeshInstanceLoader(0, Transform(4, vec3(8, 0, 8))),
		MeshInstanceLoader(0, Transform(1)),
		MeshInstanceLoader(0, Transform(1)),
		MeshInstanceLoader(1, Transform(1, vec3(5, 0, 0))),
	];

	s.animatedInstances = [
		AnimatedInstanceLoader(0, Transform(1), "FreeIdle"),
		AnimatedInstanceLoader(1, Transform(1, vec3(-6, 0, 6)), "TestAnim", true),
	];

	s.grid = Grid(GridPos(-5, 0, -5), GridPos(5, 0, 5), vec3(0,0,0));
	s.blockInstancesOffset = 2;
	s.grid.blocks = [
		GridBlock(GridPos(2, 0, 2)),
		GridBlock(GridPos(3, 0, 3))
	];

	s.grid.unmovable = [
		GridPos(5, 0, 0)
	];

	s.player = Player(&s.grid, GridPos(1,0,0));
	s.playerMeshInstance = 0;

	s.camera = Camera(vec3(0, -7, -6), 720.0/512, 60);

	return s;
}

SceneLoader testScene2()
{
	SceneLoader scene;

	with(scene)
	{
		lights = LightLoader(
			vec3(0.2, -1, 0.1),
			0.2, -6, 8,
			"data/palettes/test3.png");

		files_staticMesh = [
			"data/meshes/architecture/tower_wall01.glb",
			"data/test/meshes/tree_temperate01.glb",
			"data/test/meshes/funny-cube.glb"
		];

		files_animMesh = [
			"data/test/meshes/kitty-test.glb"
		];

		meshInstances = [
			MeshInstanceLoader(0, Transform(1, vec3(0, 0, 6.7), vec3(180, 90, 0))),
			MeshInstanceLoader(1, Transform(1, vec3(-5, 0, 2)))
		];

		animatedInstances = [
			AnimatedInstanceLoader(0, Transform(1), "FreeIdle")
		];

		grid = Grid(GridPos(-5, 0, -5), GridPos(5, 0, 5), vec3(0,0,0));
		grid.unmovable = [GridPos(-5, 0, 2)];

		player = Player(&grid, GridPos(0,0,0));
		playerMeshInstance = 0;

		camera = Camera(vec3(0, -7, -6), 720.0/512, 60);

	}

	return scene;
}