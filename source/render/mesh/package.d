// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module render.mesh;

import render.mesh.attributes;
import render.mesh.generic;

private struct SAttributes
{
	float position;
	float normal;
	float uv;
}

private struct SLoader
{
	enum position = "POSITION";
	enum normal = "NORMAL";
	enum uv = "TEXCOORD_0";
}

alias SMesh = GenericMesh!(SAttributes, SLoader);

@animated
private struct AnimAttributes
{
	float position, normal, uv;
	float bone_weight;
	uint bone_idx;
}

private struct AnimLoader
{
	enum position = "POSITION";
	enum normal = "NORMAL";
	enum uv = "TEXCOORD_0";
	enum bone_weight = "WEIGHTS_0";
	enum bone_idx = "JOINTS_0";
}

alias AnimMesh = GenericMesh!(AnimAttributes, AnimLoader);