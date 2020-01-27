// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0


module test.loading;

import std.stdio;

import gl3n.linalg;

import lanlib.file.lnb;
import lanlib.util.memory;
import logic;
import render;
import test.scenes;


// Really aggressive test of loading scenes.
void testLoading(bool testSaving=false)()
{
	SceneLoader test1 = testScene();
	SceneLoader test2 = testScene2();

	lnbStore!SceneLoader("data/scenes/test1.lnb", test1);
	lnbStore!SceneLoader("data/scenes/test2.lnb", test2);

	GameManager game = GameManager(MAX_MEMORY, "data/scenes/test1.lnb");
	
	uint loadcount1 = 0, loadcount2 = 0;

	scope(failure)
	{
		writefln("Loaded test1 %d times, test2 %d times", loadcount1, loadcount2);
	}

	for(int i = 0; i < 100; i++)
	{
		game.loadScene("data/scenes/test1.lnb");
		loadcount1++;

		game.loadScene("data/scenes/test2.lnb");
		loadcount2++;

		static if(testSaving)
		{
			lnbStore!SceneLoader("data/scenes/test1.lnb", loaded1);
			lnbStore!SceneLoader("data/scenes/test2.lnb", loaded2);
		}
	}

}

void testLoadingBlank()
{
	SceneLoader test = testSceneBlank();

	lnbStore!SceneLoader("data/scenes/testBlank.lnb", test);

	GameManager game = GameManager(MAX_MEMORY, "data/scenes/testBlank.lnb");

	for(uint loadcount = 0; loadcount < 200; loadcount++)
	{
		game.loadScene("data/scenes/testBlank.lnb");
	}
}

void testLoadingGLB(string p_file, uint p_loads)
{
	auto region = BaseRegion(MAX_MEMORY);
	assert(region.data != null);
	auto smesh = region.make!StaticMeshSystem(loadMaterial("data/shaders/worldspace3d.vert", "data/shaders/material3d.frag"));
	smesh.meshes = region.makeOwnedList!StaticMesh(4);

	auto subRegion = region.provideRemainder();
	assert(subRegion.data != null);

	for(uint loadcount = 0; loadcount < p_loads; loadcount++)
	{
		//scope(failure)
		//{
		//	writefln("Allocated %u times", loadcount);
		//}
		smesh.clearMeshes();
		subRegion.wipe();

		smesh.loadMesh(p_file, subRegion);
	}
}

void testLoadingLNT(string p_file, uint p_loads)
{
	auto region = BaseRegion(MAX_MEMORY);
	assert(region.data != null);
	auto smesh = region.make!StaticMeshSystem(loadMaterial("data/shaders/worldspace3d.vert", "data/shaders/material3d.frag"));
	smesh.meshes = region.makeOwnedList!StaticMesh(4);

	auto subRegion = region.provideRemainder();
	assert(subRegion.data != null);

	for(uint loadcount = 0; loadcount < p_loads; loadcount++)
	{
		//scope(failure)
		//{
		//	writefln("Allocated %u times", loadcount);
		//}
		smesh.clearMeshes();
		subRegion.wipe();

		smesh.loadMeshLNT(p_file, subRegion);
	}

}