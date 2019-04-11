// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0


module graphics.shaders;

import std.file;

import graphics.gl;

alias ShaderId = GLuint;

struct Shader 
{
	ShaderId id;

	this(string vert_file, string frag_file)
	{
		id = glCreateProgram();

		GLuint vert_shader = glCreateShader(GL_VERTEX_SHADER);


	}
}