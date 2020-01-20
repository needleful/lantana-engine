// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module logic.scenes.core;

import lanlib.util.memory;
import logic.grid;
import logic.input;
import logic.player;
import logic.scenes.load;

import render.mesh;
import render.lights;

struct Scene
{
	StaticMeshInstance[] staticMeshes;
	AnimatedMeshInstance[] animMeshes;
	LightInfo worldLight;
	Grid grid;
	Player player;
	ushort playerMesh, blockMesh;

	public this(
		SceneLoader p_load,
		ref StaticMeshSystem p_static,
		ref AnimatedMeshSystem p_anim,
		ILanAllocator p_alloc)
	{
		StaticMesh*[] smeshes;
		AnimatedMesh*[] ameshes;
		smeshes.reserve(p_load.files_staticMesh.length);
		ameshes.reserve(p_load.files_animMesh.length);

		foreach(meshFile; p_load.files_staticMesh)
		{
			smeshes ~= p_static.load_mesh(meshFile, p_alloc);
		}
		foreach(meshFile; p_load.files_animMesh)
		{
			ameshes ~= p_anim.load_mesh(meshFile, p_alloc);
		}

		staticMeshes = p_alloc.makeList!StaticMeshInstance(p_load.meshInstances.length);
		animMeshes = p_alloc.makeList!AnimatedMeshInstance(p_load.animatedInstances.length);

		foreach(i; 0..p_load.meshInstances.length)
		{
			auto m = &p_load.meshInstances[i];
			staticMeshes[i].mesh = smeshes[m.id];
			staticMeshes[i].transform = m.transform;
		}

		foreach(i; 0..p_load.animatedInstances.length)
		{
			auto m = &p_load.animatedInstances[i];
			animMeshes[i] = AnimatedMeshInstance(ameshes[m.id], m.transform, p_alloc);
			if(m.animation != "")
			{
				animMeshes[i].playAnimation(m.animation, m.loop);
			}
		}

		grid = p_load.grid;
		player = p_load.player;
		player.grid = &grid;
		playerMesh = p_load.playerMeshInstance;
		blockMesh = p_load.blockInstancesOffset;

		worldLight = LightInfo(p_load.lights.file_palette, p_alloc);
		worldLight.direction = p_load.lights.direction;
		worldLight.bias = p_load.lights.bias;
		worldLight.areaCeiling = p_load.lights.areaCeiling;
		worldLight.areaSpan = p_load.lights.areaSpan;
	}

	void update(Input p_input, float p_delta)
	{
		player.update(p_input, p_delta);

		animMeshes[playerMesh].transform._position = grid.getRealPosition(player.pos, player.pos_target);
		animMeshes[playerMesh].transform._rotation.y = player.dir.getRealRotation();
		if(player.previousState != player.state)
		{
			animMeshes[playerMesh].playAnimation(player.getAnimation());
		}
		else
		{
			animMeshes[playerMesh].queueAnimation(player.getAnimation());
		}

		foreach(i; 0..grid.blocks.length)
		{
			auto s = i+blockMesh;
			staticMeshes[s].transform._position = grid.getRealPosition(grid.blocks[i].position, grid.blocks[i].pos_target);
		}
	}
}