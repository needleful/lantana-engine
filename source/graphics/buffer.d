// Part of the Daisy Engine
// developed by needleful
// Licensed under GPL v3.0

module graphics.buffer;

import derelict.opengl;
mixin glFreeFuncs!(GLVersion.gl33);

import core.types;

struct VertexBuffer
{
	GLuint id;
	Vec3[] vertices;
}