// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module render.material;

debug
{
	import std.format;
	import std.stdio;
}

import lanlib.util.gl;
import lanlib.util.memory:GpuResource;
import lanlib.types;

import render.lights;

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

struct LightUniforms
{
	UniformId direction, bias;
	UniformId area_ceiling, area_span;
	UniformId palette;

	this(ref Material p_mat)
	{
		direction = p_mat.getUniformId("light_direction");
		bias = p_mat.getUniformId("light_bias");
		area_span = p_mat.getUniformId("area_span");
		area_ceiling = p_mat.getUniformId("area_ceiling");
		palette = p_mat.getUniformId("light_palette");
	}

	void set(ref Material p_mat, ref LightInfo p_info)
	{
		p_mat.setUniform(direction, p_info.direction);
		p_mat.setUniform(bias, p_info.bias);
		p_mat.setUniform(area_span, p_info.areaSpan);
		p_mat.setUniform(area_ceiling, p_info.areaCeiling);
	}
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

@GpuResource
struct Material 
{
	MaterialId matId;

	this(MaterialId p_matId) @safe @nogc nothrow
	{
		matId = p_matId;
	}

	// Move constructors

	this(Material p_rhs) @safe @nogc nothrow
	{
		matId = p_rhs.matId;
		p_rhs.matId = MaterialId(0u);
	}

	~this() @trusted @nogc nothrow
	{
		debug printf("Destroying Material: %u\n", matId);
		if(matId)
		{
			matId.glDeleteProgram();	
		}
	}

	// Move assignment
	void OpAssign(ref Material p_rhs) @nogc @safe nothrow
	{
		matId = p_rhs.matId;
		p_rhs.matId = MaterialId(0u);
	}

	const void enable() @nogc nothrow
	{
		debug 
		{
			if(!matId)
			{
				assert(false, "Tried to use Material with no ID!");
			}
		}
		matId.glUseProgram();
	}

	const bool canRender() @nogc
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
				throw new Exception(format("Cannot render Material: %s", error));
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

	UniformId getUniformId(string p_name) @nogc const
	{
		scope(exit)
		{
			glcheck();
		}

		GLint res = matId.glGetUniformLocation(p_name.ptr);
		assert(res != -1, "Missing parameter ID");

		return UniformId(res);

	}

	bool setUniform(T)(const UniformId p_uniform, auto ref T p_value) @nogc
	{
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
	AttribId getAttribId(const string p_attrib) @nogc const
	{
		scope(exit) glcheck();

		auto val = AttribId(matId.glGetAttribLocation(p_attrib.ptr));
		debug assert(val > -1, "Invalid attribute: " ~ p_attrib);
		return val;
	}

	void setAttribId(const string p_attrib, AttribId p_id) @nogc
	{
		scope(exit) glcheck();
		
		return matId.glBindAttribLocation(p_id, p_attrib.ptr);
	}
}