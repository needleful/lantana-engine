// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0


module test.loading;

import std.stdio;

import gl3n.linalg;

import lanlib.util.files;
import lanlib.util.memory;
import logic;
import render;
import test.scenes;

private struct GameManager
{
	private BaseRegion mainMem;
	private SubRegion sceneMem;
	OwnedRef!Input input;
	OwnedRef!StaticMeshSystem staticSystem;
	OwnedRef!AnimatedMeshSystem animSystem;
	OwnedRef!Scene scene;

	@disable this();

	this(size_t p_memCapacity)
	{
		mainMem = BaseRegion(p_memCapacity);

		input = mainMem.make!Input();

		staticSystem = mainMem.make!StaticMeshSystem(loadMaterial("data/shaders/worldspace3d.vert", "data/shaders/material3d.frag"));
		animSystem = mainMem.make!AnimatedMeshSystem(loadMaterial("data/shaders/animated3d.vert", "data/shaders/material3d.frag"));

		sceneMem = mainMem.provideRemainder();
	}

	void loadScene(SceneLoader p_scene, bool p_preserveCamRotation = false)
	{
		staticSystem.clearMeshes();
		animSystem.clearMeshes();

		sceneMem.wipe();

		if(p_preserveCamRotation)
		{
			vec2 rotation = scene.camera.rot;
			scene = sceneMem.make!Scene(p_scene, staticSystem, animSystem, sceneMem);
			scene.camera.rot = rotation;
		}
		else
		{
			scene = sceneMem.make!Scene(p_scene, staticSystem, animSystem, sceneMem);
		}
	}
}


// Really aggressive test of loading scenes.
void testLoading()
{
	GameManager game = GameManager(1024*1024*16);

	SceneLoader test1 = testScene();
	SceneLoader test2 = testScene2();

	storeBinary!SceneLoader("data/scenes/test1.lnt", test1);
	storeBinary!SceneLoader("data/scenes/test2.lnt", test2);

	SceneLoader loaded1;
	SceneLoader loaded2;

	uint loadcount1 = 0, loadcount2 = 0;

	scope(failure)
	{
		writefln("Loaded test1 %d times, test2 %d times", loadcount1, loadcount2);
	}

	for(int i = 0; i < 100; i++)
	{
		loaded1 = loadBinary!SceneLoader("data/scenes/test1.lnt");
		assert(test1 == loaded1);
		storeBinary!SceneLoader("data/scenes/test1.lnt", loaded1);
		loadcount1++;

		game.loadScene(loaded1);


		loaded2 = loadBinary!SceneLoader("data/scenes/test2.lnt");
		assert(test2 == loaded2);
		storeBinary!SceneLoader("data/scenes/test2.lnt", loaded2);
		loadcount2++;

		game.loadScene(loaded2);
	}

}