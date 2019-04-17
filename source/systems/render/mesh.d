// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module systems.render.mesh;

import std.file;
import std.format;
import std.stdio;

import lanlib.sys.gl;
import components.render.mesh;
import components.render.material;

/**
 *	A group of meshes with the same material.
 *  Handles creation and rendering of these meshes.
 */
struct MeshGroup
{
	Material material;
	Mesh[] meshes;

	/**
	 *	Set the material being used by this mesh, loaded from shader files
	 */
	bool load_material(const string vert_file, const string frag_file)
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
				return false;
			}
		}
		material = Material(matId);
		assert(glGetError() == GL_NO_ERROR);
		return true;
	}

	void render()
	{
		material.matId.glUseProgram();

		foreach(Mesh mesh; meshes)
		{
			glBindBuffer(GL_ARRAY_BUFFER, mesh.vbo);
			glEnableVertexAttribArray(0);

			glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, cast(const GLvoid*) 0);
			
			glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mesh.ebo);
			glDrawElements(GL_TRIANGLES, cast(int)mesh.triangles.length*3, GL_UNSIGNED_INT, cast(const GLvoid*)0);

			glcheck;
		}
	}
}

private GLuint compile_shader(string filename, GLenum type)
{
	assert(exists(filename), format("Shader file does not exist: %s", filename));

	File input = File(filename, "r");
	GLuint shader = glCreateShader(type);

	char[] s;
	s.length = input.size;
	assert(s.length > 0, format("Shader file empty: %s", filename));

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

		throw new Exception(format("Shader file did not compile: %s || %s", filename, error));
	}

	assert(glGetError() == GL_NO_ERROR);
	return shader;
}