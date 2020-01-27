// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module logic.manager;

import gl3n.linalg;

import lanlib.util.files;
import lanlib.util.memory;
import logic;
import render;

struct GameManager
{
	private BaseRegion mainMem;
	private SubRegion sceneMem;
	OwnedRef!Input input;
	OwnedRef!StaticMeshSystem staticSystem;
	OwnedRef!AnimatedMeshSystem animSystem;
	OwnedRef!Scene scene;

	@disable this();

	this(size_t p_memCapacity, string p_startScene)
	{
		mainMem = BaseRegion(p_memCapacity);

		input = mainMem.make!Input();

		staticSystem = mainMem.make!StaticMeshSystem(loadMaterial("data/shaders/worldspace3d.vert", "data/shaders/material3d.frag"));
		animSystem = mainMem.make!AnimatedMeshSystem(loadMaterial("data/shaders/animated3d.vert", "data/shaders/material3d.frag"));

		sceneMem = mainMem.provideRemainder();
		loadScene(p_startScene, false);
	}

	void loadScene(string p_file, bool p_preserveCamRotation = false)
	{
		vec2 rotation;
		if(scene) {
			rotation = scene.camera.rot;
		}

		staticSystem.clearMeshes();
		animSystem.clearMeshes();

		sceneMem.wipe();
		auto loader = loadBinary!SceneLoader(p_file);
		scene = sceneMem.make!Scene(loader, staticSystem, animSystem, sceneMem);

		if(p_preserveCamRotation)
		{
			scene.camera.rot = rotation;
		}
	}
}
