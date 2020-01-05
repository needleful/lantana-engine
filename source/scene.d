// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module scene;

import gl3n.linalg: vec3;
import lanlib.math.transform;
import logic.grid;
import logic.player;

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
	float animTime;
	ushort id;
	bool loop;

	this(ushort p_id, Transform p_transform, string p_animation, bool p_loop, float p_time = 0)
	{
		id = p_id;
		transform = p_transform;
		animation = p_animation;
		loop = p_loop;
		animTime = p_time;
	}
}

struct LevelState
{
	GridPos playerPos;
	GridPos[] blockPos;
}

struct SceneLoader
{
	/// Filename of the gridset GLB file
	string file_gridset;
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

	MeshInstanceLoader[] meshInstances;
	AnimatedInstanceLoader[] animatedInstances;
	// Index into the mesh instances for the player mesh
	ushort playerMeshInstance;
	ushort blockInstancesOffset;
}