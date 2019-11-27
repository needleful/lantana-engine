// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.sys.gl;
public import derelict.opengl;
mixin glFreeFuncs!(GLVersion.gl33);

import std.file;
import std.stdio;

import gl3n.linalg;


alias ivec2 = Vector!(int, 2);
alias ivec3 = Vector!(int, 3);
alias uvec2 = Vector!(uint, 2);
alias uvec3 = Vector!(uint, 3);
alias mat4x3 = Matrix!(float, 4, 3);

debug
{
	import std.format;
}

void glcheck() @nogc @safe
{
	debug
	{
		GLint err = glGetError();
		assert(err == GL_NO_ERROR, 
			format("OpenGL had an error: %d", err));
	}
}

GLuint compile_shader(string filename, GLenum type)
{
	debug
	{
		assert(exists(filename), format("Shader file does not exist: %s", filename));
	}

	File input = File(filename, "r");
	GLuint shader = glCreateShader(type);

	char[] s;
	s.length = input.size;
	debug 
	{
		assert(s.length > 0, format("Shader file empty: %s", filename));
	}

	input.rawRead(s);

	GLchar*[1] source = [s.ptr];
	int[1] lengths = [cast(GLint)s.length];

	shader.glShaderSource(1, source.ptr, lengths.ptr);
	shader.glCompileShader();

	GLint success;
	shader.glGetShaderiv(GL_COMPILE_STATUS, &success);
	if(!success)
	{
		GLint loglen;
		shader.glGetShaderiv(GL_INFO_LOG_LENGTH, &loglen);

		char[] error;
		error.length = loglen;
		shader.glGetShaderInfoLog(loglen, null, error.ptr);

		debug 
		{
			throw new Exception(format("Shader file did not compile: %s || %s", filename, error));
		}
		else 
		{
			printf("Error: shader did not compile: %s\n%s\n", filename.ptr, error.ptr);
			return cast(GLuint) 0;
		}
	}

	assert(glGetError() == GL_NO_ERROR);
	return shader;
}

void gl_set_uniform(T)(GLint uniform, auto ref T value) @nogc
{
	scope(exit) glcheck;

	static if (is(T == vec4))
	{
		uniform.glUniform4f(value.x, value.y, value.z, value.w);
	}
	else static if (is(T == vec4[]))
	{
		uniform.glUniform4fv(value.length, value.ptr);
	}
	else static if (is(T == vec3))
	{
		uniform.glUniform3f(value.x, value.y, value.z);
	}
	else static if (is(T == vec3[]))
	{
		uniform.glUniform3fv(value.length, value.ptr);
	}
	else static if (is(T == vec2))
	{
		uniform.glUniform2f(value.x, value.y);
	}
	else static if (is(T == vec2[]))
	{
		uniform.glUniform2fv(value.length, value.ptr);
	}

	else static if (is(T == ivec3))
	{
		uniform.glUniform3i(value.x, value.y, value.z);
	}
	else static if (is(T == ivec2))
	{
		uniform.glUniform2i(value.x, value.y);
	}

	else static if (is(T == uvec3))
	{
		uniform.glUniform3ui(value.x, value.y, value.z);
	}
	else static if (is(T == uvec2))
	{
		uniform.glUniform2ui(value.x, value.y);
	}

	else static if (is(T == mat4))
	{
		uniform.glUniformMatrix4fv(1, GL_TRUE, &value[0][0]);
	}
	else static if (is(T == mat4[]))
	{
		uniform.glUniformMatrix4fv(cast(int)value.length, GL_TRUE, &value[0][0][0]);
	}
	else static if (is(T == mat4x3))
	{
		uniform.glUniformMatrix4x3fv(1, GL_TRUE, &value[0][0]);
	}
	else static if (is(T == mat4x3[]))
	{
		uniform.glUniformMatrix4x3fv(cast(int)value.length, GL_TRUE, &value[0][0][0]);
	}
	else static if (is(T == mat3))
	{
		uniform.glUniformMatrix3fv(1, GL_TRUE, &value[0][0]);
	}
	else static if (is(T == mat3[]))
	{
		uniform.glUniformMatrix3fv(cast(int)value.length, GL_TRUE, &value[0][0][0]);
	}
	else static if (is(T == mat2))
	{
		uniform.glUniformMatrix2fv(1, GL_TRUE, &value[0][0]);
	}
	else static if (is(T == mat2[]))
	{
		uniform.glUniformMatrix2fv(cast(int)value.length, GL_TRUE, &value[0][0][0]);
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
		static assert(false, "This type is not supported as a uniform: "~T.stringof);
	}
}