// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module render.material;

import std.format;

import lanlib.sys.gl;

alias MaterialId = GLuint;
alias UniformId = GLuint;

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

	bool set_param(T)(const string param, auto ref T value) @nogc
	{
		scope(exit) 
		{
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