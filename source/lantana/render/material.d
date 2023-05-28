// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.render.material;

debug
{
	import std.format;
	import std.stdio;
}

import lantana.render.gl;
import lantana.render.lights;
import lantana.types.core;

struct MaterialId
{
	mixin StrictAlias!GLuint;
}
struct UniformId
{
	mixin StrictAlias!GLint;
}
struct AttribId
{
	mixin StrictAlias!GLint;
}

Material loadMaterial(const string p_vertFile, const string p_fragFile)
{
	GLuint matId = glCreateProgram();

	GLuint vertShader = compileShader(p_vertFile, GL_VERTEX_SHADER);
	GLuint fragShader = compileShader(p_fragFile, GL_FRAGMENT_SHADER);

	matId.glAttachShader(vertShader);
	matId.glAttachShader(fragShader);

	bool success = linkShader(matId);
	
	glcheck();

	if(!success)
		return Material(MaterialId(cast(uint)0));
	else
		return Material(MaterialId(matId));
}

struct Material 
{
	MaterialId matId;

	this(MaterialId p_matId)  nothrow
	{
		matId = p_matId;
	}

	// Move constructors

	this(ref Material p_rhs)  nothrow
	{
		matId = p_rhs.matId;
		p_rhs.matId = MaterialId(0u);
	}

	~this() @trusted nothrow
	{
		debug printf("Destroying Material: %lu\n", matId._handle);
		if(matId)
		{
			matId.glDeleteProgram();
			//assert(false, format("Deleting valid material: %u", matId.handle()));
		}
	}

	// Move assignment
	void OpAssign(ref Material p_rhs)  nothrow
	{
		matId = p_rhs.matId;
		p_rhs.matId = MaterialId(0u);
	}

	const void enable()
	{
		debug 
		{
			if(!matId)
			{
				assert(false, "Tried to use Material with no ID!");
			}
		}
		matId.glUseProgram();
		glcheck();
	}

	const bool canRender() 
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
				assert(false, format("Cannot render Material: %s", error));
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

	UniformId getUniformId(string p_name) const
	{
		scope(exit)
		{
			glcheck();
		}

		GLint res = matId.glGetUniformLocation(p_name.ptr);
		return UniformId(res);
	}

	bool setUniform(T)(const UniformId p_uniform, auto ref T p_value) 
	{
		scope(failure)
		{
			debug writefln("Failed to set %s uniform: %s", T.stringof, p_value);
			else return false;
		}
		if(p_uniform == -1)
		{
			return false;
		}
		else
		{
			scope(exit) 
			{
				glcheck();
			}
			enable();
			
			static if(is(T == double))
			{
				pragma(msg, "Notice: Doubles are automatically converted to floats when setting uniforms");
				gl_setUniform!float(p_uniform, cast(float)p_value);
				return true;
			}
			else
			{
				gl_setUniform!T(p_uniform, p_value);
				return true;
			}
		}
	}
	AttribId getAttribId(const string p_attrib) const
	{
		scope(exit) glcheck();

		auto val = AttribId(matId.glGetAttribLocation(p_attrib.ptr));
		
		debug if(val <= -1)
		{
			printf("Invalid attribute: %s\n", p_attrib.ptr);
			assert(false);
		}
		return val;
	}

	void setAttribId(const string p_attrib, AttribId p_id) 
	{
		scope(exit) glcheck();
		
		return matId.glBindAttribLocation(p_id, p_attrib.ptr);
	}
}