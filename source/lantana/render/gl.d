// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.render.gl;
public import bindbc.opengl;

import std.file;
import std.stdio;

import lantana.math.matrix;
import lantana.math.vectors;

debug
{
	import std.format;
}

void glcheck() @nogc
{
	string errorString(GLint err) @nogc
	{
		switch(err)
		{
			case GL_NO_ERROR:
				return "No Error";
			case GL_INVALID_ENUM:
				return "Invalid Enum";
			case GL_INVALID_VALUE:
				return "Invalid Value";
			case GL_INVALID_OPERATION:
				return "Invalid Operation";
			case GL_INVALID_FRAMEBUFFER_OPERATION:
				return "Invalid Framebuffer Operation";
			case GL_OUT_OF_MEMORY:
				return "Out of Memory";
			default:
				return "Unknown Error";
		}
	}

	GLint err = glGetError();
	if(err != GL_NO_ERROR)
	{
		printf("OpenGL had an error: %u (%X), %s\n", err, err, errorString(err).ptr);
		debug assert(false, 
			format("OpenGL had an error: %u (%X), %s", err, err, errorString(err)));
	}
}

bool linkShader(GLuint p_program)
{
	p_program.glLinkProgram();

	GLint success;
	p_program.glGetProgramiv(GL_LINK_STATUS, &success);

	if(!success)
	{
		debug
		{
			GLint loglen;
			p_program.glGetProgramiv(GL_INFO_LOG_LENGTH, &loglen);

			char[] error;
			error.length = loglen;

			p_program.glGetProgramInfoLog(cast(GLint)error.length, null, error.ptr);
			throw new Exception(format("Failed to link program: %s", error));
		}
		else
		{
			return false;
		}
	}

	return true;
}

GLuint compileShader(string filename, GLenum type)
{
	glcheck();
	debug
	{
		assert(exists(filename), format("Shader file does not exist: %s", filename));
	}

	File input = File(filename, "r");
	GLuint shader = glCreateShader(type);

	char[] s;
	s.length = cast(size_t) input.size;
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

	glcheck();
	return shader;
}

void gl_setUniform(T)(GLint uniform, auto ref T value) 
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

	else static if (is(T == iVec3))
	{
		uniform.glUniform3i(value.x, value.y, value.z);
	}
	else static if (is(T == iVec2))
	{
		uniform.glUniform2i(value.x, value.y);
	}

	else static if (is(T == uVec3))
	{
		uniform.glUniform3ui(value.x, value.y, value.z);
	}
	else static if (is(T == uVec2))
	{
		uniform.glUniform2ui(value.x, value.y);
	}

	else static if (is(T == Mat4))
	{
		uniform.glUniformMatrix4fv(1, GL_TRUE, value.ptr);
	}
	else static if (is(T == Mat4[]))
	{
		uniform.glUniformMatrix4fv(cast(int)value.length, GL_TRUE, value[0].ptr);
	}
	else static if (is(T == Mat4x3))
	{
		uniform.glUniformMatrix4x3fv(1, GL_TRUE, value.ptr);
	}
	else static if (is(T == Mat4x3[]))
	{
		uniform.glUniformMatrix4x3fv(cast(int)value.length, GL_TRUE, value[0].ptr);
	}
	else static if (is(T == Mat3))
	{
		uniform.glUniformMatrix3fv(1, GL_TRUE, &value[0][0]);
	}
	else static if (is(T == Mat3[]))
	{
		uniform.glUniformMatrix3fv(cast(int)value.length, GL_TRUE, value[0].ptr);
	}
	else static if (is(T == Mat2))
	{
		uniform.glUniformMatrix2fv(1, GL_TRUE, value.ptr);
	}
	else static if (is(T == Mat2[]))
	{
		uniform.glUniformMatrix2fv(cast(int)value.length, GL_TRUE, value[0].ptr);
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