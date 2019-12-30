// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module render.lights;

import gl3n.linalg: vec3;

struct LightInfo
{
	public vec3 color;
	public vec3 direction;
	public vec3 ambiance;
	public float bias;
}