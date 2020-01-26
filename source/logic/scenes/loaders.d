// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module logic.scenes.load;

import gl3n.linalg: vec3;

import lanlib.math.transform;
import lanlib.util.memory;

import logic.grid;
import logic.player;
import logic.scenes.core;
import render.camera;
import render.mesh;

struct LightLoader
{
	vec3 direction;
	float bias;
	float areaCeiling, areaSpan;
	string file_palette;

	this(vec3 p_direction, float p_bias, float p_areaCeiling, float p_areaSpan, string p_palette)
	{
		direction = p_direction;
		bias = p_bias;
		areaCeiling = p_areaCeiling;
		areaSpan = p_areaSpan;
		file_palette = p_palette;
	}
}

struct MeshInstanceLoader
{
	Transform transform;
	ushort id;

	this(ushort p_id, Transform p_transform)
	{
		id = p_id;
		transform = p_transform;
	}
}

struct AnimatedInstanceLoader
{
	string animation;
	Transform transform;
	ushort id;
	bool loop;

	this(ushort p_id, Transform p_transform, string p_animation = "", bool p_loop = false)
	{
		id = p_id;
		transform = p_transform;
		animation = p_animation;
		loop = p_loop;
	}
}

struct LevelState
{
	GridPos playerPos;
	GridPos[] blockPos;
}

struct SceneLoader
{
	/// Filename of the next scene
	string file_nextScene;
	/// List of static mesh GLBs
	string[] files_staticMesh;
	/// List of animated mesh GLBs
	string[] files_animMesh;
	/// For reconstructing LightInfo
	LightLoader lights;
	/// The level itself
	Grid grid;
	/// Player's location on the grid
	Player player;

	Camera camera;

	MeshInstanceLoader[] meshInstances;
	AnimatedInstanceLoader[] animatedInstances;
	// Index into the mesh instances for the player mesh
	ushort playerMeshInstance;
	// First index of a block's mesh instance.  Blocks are assumed to be next to each other
	ushort blockInstancesOffset;
}