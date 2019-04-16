// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module graphics.gl;
public import derelict.opengl;
mixin glFreeFuncs!(GLVersion.gl33);

import std.format;

import common.math.vector;
import common.math.matrix;

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

	static if (is(T == Vec4))
	{
		uniform.glUniform4f(value.x, value.y, value.z, value.w);
	}
	else static if (is(T == Vec4[]))
	{
		uniform.glUniform4fv(value.length, value.ptr);
	}
	else static if (is(T == Vec3))
	{
		uniform.glUniform3f(value.x, value.y, value.z);
	}
	else static if (is(T == Vec3[]))
	{
		uniform.glUniform3fv(value.length, value.ptr);
	}
	else static if (is(T == Vec2))
	{
		uniform.glUniform2f(value.x, value.y);
	}
	else static if (is(T == Vec2[]))
	{
		uniform.glUniform2fv(value.length, value.ptr);
	}

	else static if (is(T == Mat4))
	{
		uniform.glUniformMatrix4fv(1, GL_FALSE, value.bytes);
	}
	else static if (is(T == Mat4[]))
	{
		uniform.glUniformMatrix4fv(cast(int)value.length, GL_FALSE, value[0].bytes);
	}
	else static if (is(T == Mat3))
	{
		uniform.glUniformMatrix3fv(1, GL_FALSE, value.bytes);
	}
	else static if (is(T == Mat3[]))
	{
		uniform.glUniformMatrix3fv(cast(int)value.length, GL_FALSE, value[0].bytes);
	}
	else static if (is(T == Mat2))
	{
		uniform.glUniformMatrix2fv(1, GL_FALSE, value.bytes);
	}
	else static if (is(T == Mat2[]))
	{
		uniform.glUniformMatrix2fv(cast(int)value.length, GL_FALSE, value[0].bytes);
	}

	else static if (is(T == float))
	{
		uniform.glUniform1f(value);
	}
	else static if (is(T == float[]))
	{
		uniform.glUniform1fv(value.length, value.ptr);
	}
	else static if (is(T == int))
	{
		uniform.glUniform1i(value);
	}
	else static if (is(T == int[]))
	{
		uniform.glUniform1iv(value.length, value.ptr);
	}
	else static if (is(T == uint))
	{
		uniform.glUniform1ui(value);
	}
	else static if (is(T == uint[]))
	{
		uniform.glUniform1uiv(value.length, value.ptr);
	}
	else
	{
		static assert(false, "This type is not supported as a uniform");
	}
}