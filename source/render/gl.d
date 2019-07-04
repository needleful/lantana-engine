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
			// TODO: implement more messaging
			const(char)[] s = message[0..length];
			printf("GL: %s", s.ptr);
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
			// TODO: implement more messaging
			string s = message[0..length];
			writeln("GL: ", s);
		}
	}
}