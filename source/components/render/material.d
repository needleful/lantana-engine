// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module components.render.material;

import std.format;

import lanlib.sys.gl;

alias MaterialId = GLuint;
alias UniformId = GLuint;

struct Material 
{
	MaterialId matId;

	@nogc this(GLuint matId)
	{
		this.matId = matId;
	}

	@nogc const bool can_render()
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

	@nogc const UniformId get_param_id(string param)
	{
		scope(exit)
		{
			glUseProgram(0);
			glcheck;
		}
		matId.glUseProgram();

		return matId.glGetUniformLocation(param.ptr);

	}

	@nogc bool set_param(T)(const string param, auto ref T value)
	{
		scope(exit) 
		{
			glUseProgram(0);
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

	@nogc bool set_param(T)(const UniformId uniform, auto ref T value)
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