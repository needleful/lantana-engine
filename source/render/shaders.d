// Lantana
// shaders.d
// Licensed under GPL v3.0

/// Module containing all shaders and shader related code
module lantana.render.shaders;

import lantana.render.gl;

import std.stdio;

GLuint MakeShader(GLuint shaderType, char[] source) @nogc nothrow
{
	GLuint s = glCreateShader(shaderType);
	char* ptr = source.ptr;
	glShaderSource(s, 1, &ptr, cast(const(int)*)null);
	glCompileShader(s);

	GLint status;
	glGetShaderiv(s, GL_COMPILE_STATUS, &status);

	if(status != GL_TRUE)
	{
		char[512] error;
		glGetShaderInfoLog(s, 512, cast(int*)null, &error[0]);
		error[511] = '\0';
		puts(&error[0]);

		describe_string(source);
	}

	return s;
}

GLuint CompileShader(GLuint shaderType, const(char*) source) @nogc nothrow
{
	import core.stdc.stdlib;
	debug printf("Compiling shader: %s\n", source);

	FILE* file = fopen(source, "r");
	scope(exit)
	{
		fclose(file);
	}

	if(!file)
	{
		printf("Failed to open shader file: %s\n", source);
		return 0;
	}

	fseek(file, 0L, SEEK_END);
	uint shaderSize = ftell(file);
	rewind(file);

	char[] shaderString = (cast(char*)malloc(char.sizeof * shaderSize))[0..shaderSize];
	scope(exit) free(shaderString.ptr);

	size_t realSize = fread(shaderString.ptr, char.sizeof, shaderSize, file);

	shaderString[realSize] = '\0';

	printf("Shader string (%u bytes, %u real bytes):\n", shaderSize, realSize);

	return MakeShader(shaderType, shaderString);
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

void describe_string(char[] s) @nogc nothrow
{
	void describe_char(char c)
	{
		switch(c)
		{
			case '\n':
				printf("[ \\n]: ");
				break;
			case '\t':
				printf("[ \\t]: ");
				break;
			case '\r':
				printf("[ \\r]: ");
				break;
			default:
				printf("[%3c]: ", c);
				break;
		}
		printf("%3u", cast(uint)c);
	}

	foreach(i; 0..s.length)
	{
		char c = s[i];
		printf("%4d ", i);
		describe_char(c);
		printf("\t");
		if(i % 8 == 0)
		{
			printf("\n");
		}
	}
}