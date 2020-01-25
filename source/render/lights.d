// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module render.lights;

import gl3n.linalg: vec3;

import lanlib.types;
import lanlib.util.gl;
import lanlib.util.memory;
import render.textures;

struct LightInfo
{
	Texture!Color palette;
	vec3 direction;
	float bias;
	float areaCeiling, areaSpan;
	
	public this(string p_palette_file, ref Region p_alloc)
	{
		palette = Texture!Color(p_palette_file, true, p_alloc);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	}
}