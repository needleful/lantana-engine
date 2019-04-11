// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module graphics.gl;
public import derelict.opengl;
mixin glFreeFuncs!(GLVersion.gl33);

import std.format;

import core.types;

void glcheck()
{
	debug
	{
		GLint err = glGetError();
		assert(err == GL_NO_ERROR, 
			format("OpenGL had an error: %d", err));
	}
}

void set_uniform(T)(GLint uniform, T value)
{
	scope(exit) glcheck;

	static assert(false, "This type is not supported as a uniform");
}

void set_uniform(T: Vec4)(GLint uniform, Vec4 value)
{
	uniform.glUniform4f(value.x, value.y, value.z, value.w);
}

void set_uniform(T: Vec4[])(GLint uniform, Vec4[] value)
{
	uniform.glUniform4fv(value.length, value.ptr);
}

void set_uniform(T: Vec3)(GLint uniform, Vec3 value)
{
	uniform.glUniform3f(value.x, value.y, value.z);
}

void set_uniform(T: Vec3[])(GLint uniform, Vec3[] value)
{
	uniform.glUniform3fv(value.length, value.ptr);
}

void set_uniform(T: Vec2)(GLint uniform, Vec2 value)
{
	uniform.glUniform2f(value.x, value.y);
}

void set_uniform(T: Vec2[])(GLint uniform, Vec2[] value)
{
	uniform.glUniform2fv(value.length, value.ptr);
}

void set_uniform(T: float)(GLint uniform, float value)
{
	uniform.glUniform1f(value);
}

void set_uniform(T: float[])(GLint uniform, float[] value)
{
	uniform.glUniform1fv(value.length, value.ptr);
}

void set_uniform(T: int)(GLint uniform, int value)
{
	uniform.glUniform1i(value);
}

void set_uniform(T: int[])(GLint uniform, int[] value)
{
	uniform.glUniform1iv(value.length, value.ptr);
}

void set_uniform(T: uint)(GLint uniform, uint value)
{
	uniform.glUniform1ui(value);
}

void set_uniform(T: uint[])(GLint uniform, uint[] value)
{
	uniform.glUniform1uiv(value.length, value.ptr);
}