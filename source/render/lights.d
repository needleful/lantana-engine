// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module render.lights;

import gl3n.linalg: vec3;

struct LightInfo
{
	vec3 direction;
	float bias;
	float areaCeiling, areaSpan;
}