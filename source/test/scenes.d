// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module test.scenes;

import gl3n.linalg: vec3;

import lanlib.math.transform;
import lanlib.util.memory;
import logic.grid;
import logic.player;
import logic.scene;

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
		"data/test/meshes/funny-cube.glb"
	];

	s.files_animMesh = [
		"data/test/meshes/anim_test.glb",
		"data/test/meshes/kitty-test.glb"
	];

	s.meshInstances = [
		MeshInstanceLoader(0, Transform(4, vec3(0, 5, 0))),
		MeshInstanceLoader(0, Transform(4, vec3(8, 0, 8))),
		MeshInstanceLoader(0, Transform(1)),
		MeshInstanceLoader(0, Transform(1))
	];

	s.animatedInstances = [
		AnimatedInstanceLoader(0, Transform(1, vec3(-6, 0, 6)), "TestAnim", true),
		AnimatedInstanceLoader(1, Transform(1), "FreeIdle")
	];


	s.grid = Grid(GridPos(-5, 0, -5), GridPos(5, 0, 5), vec3(0,0,0));
	s.blockInstancesOffset = 2;
	s.grid.blocks = [
		GridBlock(GridPos(2, 0, 2)),
		GridBlock(GridPos(3, 0, 3))
	];

	s.player = Player(&s.grid, GridPos(0,0,0));
	s.playerMeshInstance = 1;

	return s;
}