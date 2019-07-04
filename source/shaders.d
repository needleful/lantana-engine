// Lantana
// shaders.d
// Licensed under GPL v3.0

/// Module containing all shaders and shader related code
module lantana.shaders;

import lantana.gl;

import std.stdio;

immutable const(char)[] textShaderVert_source = "
#version 400
uniform ivec2 translation;
uniform uvec2 screen_size;

layout(location = 0) in ivec2 vert_position;
layout(location = 1) in vec2 vert_uv;

out vec2 frag_uv;

void main()
{
	ivec2 pos = vert_position + translation;
	vec2 pos_norm = pos*2.0/screen_size;
	frag_uv = vert_uv;
	gl_Position = vec4(pos_norm - vec2(1, 1), 0.0, 1.0);
}";

immutable const(char)[] textShaderFrag_source = "
#version 400

uniform vec4 color;
uniform sampler2D alpha;

in vec2 frag_uv;

out vec4 out_color;

void main()
{
	float a = texture(alpha, frag_uv).r;
	out_color = color * vec4(frag_uv,a,1);
}";

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