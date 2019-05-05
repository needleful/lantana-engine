// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module render.material;

debug
{
	import std.format;
	import std.stdio;
}

import lanlib.sys.gl;
import lanlib.sys.memory:GpuResource;

alias MaterialId = GLuint;
alias UniformId = GLuint;
alias AttribId = GLuint;

Material load_material(const string vert_file, const string frag_file)
{
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
			return Material(0);
		}
	}

	glcheck();
	return Material(matId);
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
		rhs.matId = 0;
	}

	this(ref Material rhs) @safe @nogc nothrow
	{
		this.matId = rhs.matId;
		rhs.matId = 0;
	}

	~this() @trusted @nogc nothrow
	{
		debug
		{
			printf("Destroying material: %u\n", matId);
		}
		if(matId)
		{
			matId.glDeleteProgram();	
		}
	}

	// Move assignment
	void OpAssign(ref Material rhs) @nogc @safe nothrow
	{
		this.matId = rhs.matId;
		rhs.matId = 0;
	}

	const void enable() @nogc nothrow
	{
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

	UniformId get_param_id(string param) @nogc const
	{
		scope(exit)
		{
			glcheck();
		}

		return matId.glGetUniformLocation(param.ptr);

	}

	UniformId set_param(T)(const string param, auto ref T value) @nogc
	{
		scope(exit) 
		{
			glcheck();
		}

		GLuint uniform = matId.glGetUniformLocation(param.ptr);

		debug {
			assert(uniform != -1, format("Missing uniform location: %s", param ));
		}

		set_param!T(uniform, value);

		return uniform;
	}

	bool set_param(T)(const UniformId uniform, auto ref T value) @nogc
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
	AttribId get_attrib_id(string attrib) @nogc const
	{
		scope(exit) glcheck();

		return matId.glGetAttribLocation(attrib.ptr);
	}

	void set_attrib_id(string attrib, AttribId id) @nogc
	{
		scope(exit) glcheck();
		
		return matId.glBindAttribLocation(id, attrib.ptr);
	}
}