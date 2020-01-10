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
		direction = p_mat.get_uniform_id("light_direction");
		bias = p_mat.get_uniform_id("light_bias");
		area_span = p_mat.get_uniform_id("area_span");
		area_ceiling = p_mat.get_uniform_id("area_ceiling");
		palette = p_mat.get_uniform_id("light_palette");
	}

	void set(ref Material p_mat, ref LightInfo p_info)
	{
		p_mat.set_uniform(direction, p_info.direction);
		p_mat.set_uniform(bias, p_info.bias);
		p_mat.set_uniform(area_span, p_info.areaSpan);
		p_mat.set_uniform(area_ceiling, p_info.areaCeiling);
	}
}

Material loadMaterial(const string vert_file, const string frag_file)
{
	GLuint matId = glCreateProgram();

	GLuint vert_shader = compile_shader(vert_file, GL_VERTEX_SHADER);
	GLuint frag_shader = compile_shader(frag_file, GL_FRAGMENT_SHADER);

	matId.glAttachShader(vert_shader);
	matId.glAttachShader(frag_shader);

	bool success = link_shader(matId);
	
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

	this(MaterialId matId) @safe @nogc nothrow
	{
		this.matId = matId;
	}

	// Move constructors

	this(Material rhs) @safe @nogc nothrow
	{
		this.matId = rhs.matId;
		rhs.matId = MaterialId(0u);
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
	void OpAssign(ref Material rhs) @nogc @safe nothrow
	{
		this.matId = rhs.matId;
		rhs.matId = MaterialId(0u);
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

	UniformId get_uniform_id(string param) @nogc const
	{
		scope(exit)
		{
			glcheck();
		}

		GLint res = matId.glGetUniformLocation(param.ptr);
		assert(res != -1, "Missing parameter ID");

		return UniformId(res);

	}

	UniformId set_uniform(T)(const string param, auto ref T value) @nogc
	{
		scope(exit) 
		{
			glcheck();
		}

		UniformId uniform = UniformId(matId.glGetUniformLocation(param.ptr));

		debug {
			assert(uniform != -1, format("Missing uniform location: %s", param ));
		}

		set_uniform!T(uniform, value);

		return uniform;
	}

	bool set_uniform(T)(const UniformId uniform, auto ref T value) @nogc
	{
		if(uniform == -1)
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
				gl_set_uniform!float(uniform, cast(float)value);
				return true;
			}
			else
			{
				gl_set_uniform!T(uniform, value);
				return true;
			}
		}
	}
	AttribId get_attrib_id(const string attrib) @nogc const
	{
		scope(exit) glcheck();

		auto val = AttribId(matId.glGetAttribLocation(attrib.ptr));
		debug assert(val > -1, "Invalid attribute: " ~ attrib);
		return val;
	}

	void set_attrib_id(const string attrib, AttribId id) @nogc
	{
		scope(exit) glcheck();
		
		return matId.glBindAttribLocation(id, attrib.ptr);
	}
}