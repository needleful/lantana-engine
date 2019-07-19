// Lantana
// gl.d
// Licensed under GPL v3.0

/// Module defining OpenGL functionality
module lantana.render.gl;

public import derelict.opengl;
mixin glFreeFuncs!(GLVersion.gl43);

version(Windows)
{
	extern(Windows)
	void logMessage(
		GLenum source, GLenum type, GLuint id, GLenum severity, 
		GLsizei length, const(GLchar*) message, 
		const(void*) userParams ) @nogc pure nothrow
	{
		debug
		{
			import core.stdc.stdio;
			printf("GL: %s\n", message);
		}
	}
}
else
{
	extern(C)
	void logMessage(
		GLenum source, GLenum type, GLuint id, GLenum severity, 
		GLsizei length, const(GLchar*) message, 
		const(void*) userParams ) @nogc pure nothrow
	{
		debug
		{
			import core.stdc.stdio;
			printf("GL: %s\n", message);
		}
	}
}

void glCheck() @nogc
{
	auto err=  glGetError();
	if(err != GL_NO_ERROR)
	{
		import core.stdc.stdio;
		printf("GL Error: %d\n", err);
	}
}