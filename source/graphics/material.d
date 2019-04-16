// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module graphics.material;

import std.file;
import std.format;
import std.stdio;

import graphics.gl;

alias MaterialId = GLuint;

struct Material 
{
	MaterialId matId;

	this(const string vert_file, const string frag_file)
	{
		matId = glCreateProgram();

		GLuint vert_shader = compile_shader(vert_file, GL_VERTEX_SHADER);
		GLuint frag_shader = compile_shader(frag_file, GL_FRAGMENT_SHADER);

		matId.glAttachShader(vert_shader);
		matId.glAttachShader(frag_shader);

		matId.glLinkProgram();

		GLint success;
		matId.glGetProgramiv(GL_LINK_STATUS, &success);

		if(!success)
		{
			GLint loglen;
			matId.glGetProgramiv(GL_INFO_LOG_LENGTH, &loglen);

			char[] error;
			error.length = loglen;

			matId.glGetProgramInfoLog(cast(GLint)error.length, null, error.ptr);
			throw new Exception(format(
				"Failed to link program: %s || %s || %s", vert_file, frag_file, error));
		}
		assert(glGetError() == GL_NO_ERROR);
	}

	bool can_render()
	{
		scope(exit) assert(glGetError() == GL_NO_ERROR);

		matId.glValidateProgram();
		GLint success;
		matId.glGetProgramiv(GL_VALIDATE_STATUS, &success);

		if(!success)
		{
			debug {
				GLint loglen;
				matId.glGetProgramiv(GL_INFO_LOG_LENGTH, &loglen);

				char[] error;
				error.length = loglen;

				matId.glGetProgramInfoLog(cast(GLint)error.length, null, error.ptr);
				throw new Exception(format("Cannot render material: %s", error));
			}
			else
			{
				return false;
			}
		}
		else {
			return true;
		}
	}

	bool set_param(T)(string param, T value)
	{
		scope(exit) 
		{
			glUseProgram(0);
			glcheck();
		}

		matId.glUseProgram();

		GLint uniform = matId.glGetUniformLocation(param.ptr);

		if(uniform == -1)
		{
			debug{
				throw new Exception(format(
					"Could not find material parameter of type %s: %s", T.stringof, param));
			}
			else
			{
				return false;
			}
		}
		else
		{
			static if(is(T == double))
			{
				pragma(msg, "Notice: Doubles are automatically converted to floats when setting uniforms");
				set_uniform!float(uniform, cast(float)value);
				return true;
			}
			else
			{
				set_uniform!T(uniform, value);
				return true;
			}
		}
	}
}

private GLuint compile_shader(string filename, GLenum type)
{
	assert(exists(filename), format("Shader file does not exist: %s", filename));

	File input = File(filename, "r");
	GLuint shader = glCreateShader(type);

	char[] s;
	s.length = input.size;
	assert(s.length > 0, format("Shader file empty: %s", filename));

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

		throw new Exception(format("Shader file did not compile: %s || %s", filename, error));
	}

	assert(glGetError() == GL_NO_ERROR);
	return shader;
}