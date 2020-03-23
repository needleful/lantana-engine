// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.skybox;

import gl3n.linalg;
import lanlib.types;
import render.mesh.generic;
import render.textures;

struct SkyboxAttributes
{
	vec3 color;
	vec3 position;
	vec2 uv;
}

struct SkyboxLoader
{
	enum color = "COLOR_0";
	enum position = "POSITION";
	enum uv = "TEXCOORD_0";
}

struct SkyboxUniforms
{
	mat4 projection;
	float gamma;
	int tex_albedo;
}

struct SkyboxSettings
{
	enum alphaBlend = true;
	enum depthTest = false;
	enum depthWrite = false;
	enum filter = Filter(TexFilter.Linear);
	alias textureType = Color;
}

alias SkyMesh = GenericMesh!(SkyboxAttributes, SkyboxLoader, SkyboxUniforms, SkyboxSettings);