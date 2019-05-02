// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.render.material;

import std.format;
import std.stdio;

import lanlib.sys.gl;

alias MaterialId = GLuint;
alias UniformId = GLuint;


Material load_material(const string vert_file, const string frag_file)
{
	scope(exit) assert(glGetError() == GL_NO_ERROR);
	GLuint matId = glCreateProgram();

	GLuint vert_shader = compile_shader(vert_file, GL_VERTEX_SHADER);
	GLuint frag_shader = compile_shader(frag_file, GL_FRAGMENT_SHADER);

	matId.glAttachShader(vert_shader);
	matId.glAttachShader(frag_shader);

	matId.glLinkProgram();

	GLint success;
	matId.glGetProgramiv(GL_LINK_STATUS, &success);

	if(!success)
	{
		debug
		{
			GLint loglen;
			matId.glGetProgramiv(GL_INFO_LOG_LENGTH, &loglen);

			char[] error;
			error.length = loglen;

			matId.glGetProgramInfoLog(cast(GLint)error.length, null, error.ptr);
			throw new Exception(format(
			"Failed to link program: %s || %s || %s", vert_file, frag_file, error));
		}
		else
		{
			return Material(-1);
		}
	}
	return Material(matId);
}

struct Material 
{
	MaterialId matId;

	this(MaterialId matId) @safe @nogc nothrow
	{
		this.matId = matId;
	}

	const void enable() @nogc
	{
		assert(can_render());
		matId.glUseProgram();
	}

	const bool can_render() @nogc
	{
		scope(exit) glcheck;

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

	const UniformId get_param_id(string param) @nogc
	{
		scope(exit)
		{
			glUseProgram(0);
			glcheck;
		}
		matId.glUseProgram();

		return matId.glGetUniformLocation(param.ptr);

	}

	// Returns the ID of the param for more efficient setting next time
	// returns -1 if there was no parameter of this name
	UniformId set_param(T)(const string param, auto ref T value) @nogc
	{
		scope(exit) 
		{
			//glUseProgram(0);
			glcheck();
		}

		matId.glUseProgram();

		GLuint uniform = matId.glGetUniformLocation(param.ptr);

		if(uniform == -1)
		{
			debug{
				throw new Exception(format(
					"Could not find material parameter of type %s: %s", T.stringof, param));
			}
		}
		else
		{
			static if(is(T == double))
			{
				pragma(msg, "Notice: Doubles are automatically converted to floats when setting uniforms");
				set_uniform!float(uniform, cast(float)value);
			}
			else
			{
				set_uniform!T(uniform, value);
			}
		}
		return uniform;
	}

	bool set_param(T)(const UniformId uniform, auto ref T value) @nogc
	{

		if(uniform == -1)
		{
			debug{
				throw new Exception(format(
					"No uniform of type %s with id %u", T.stringof, uniform));
			}
			else
			{
				return false;
			}
		}
		else
		{
			scope(exit) 
			{
				glUseProgram(0);
				glcheck();
			}
			
			matId.glUseProgram();

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