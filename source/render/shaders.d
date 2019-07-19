// Lantana
// shaders.d
// Licensed under GPL v3.0

/// Module containing all shaders and shader related code
module lantana.render.shaders;

import lantana.render.gl;

import std.stdio;

GLuint MakeShader(GLuint shaderType, const(char)* source) @nogc nothrow
{
	GLuint s = glCreateShader(shaderType);
	glShaderSource(s, 1, &source, cast(const(int)*)null);
	glCompileShader(s);

	GLint status;
	glGetShaderiv(s, GL_COMPILE_STATUS, &status);

	if(status != GL_TRUE)
	{
		char[512] error;
		glGetShaderInfoLog(s, 512, cast(int*)null, &error[0]);
		error[511] = '\0';
		puts(&error[0]);
	}

	return s;
}

GLuint LinkShaders(GLuint[] shaders) @nogc nothrow
{
	GLuint program = glCreateProgram();

	foreach(shader; shaders)
	{
		glAttachShader(program, shader);
	}

	glLinkProgram(program);

	foreach(shader; shaders)
	{
		glDeleteShader(shader);
	}

	GLint success;
	glGetProgramiv(program, GL_LINK_STATUS, &success);
	if(success != GL_TRUE)
	{
		char[512] error;
		glGetProgramInfoLog(program, 512, cast(int*)null, &error[0]);
		error[511] = '\0';
		printf("Failed to link shader program: %s\n", &error[0]);
		return 0;
	}
	return program;
}