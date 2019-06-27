// Lantana
// gl.d
// Licensed under GPL v3.0

/// Module defining OpenGL functionality
module lantana.gl;

public import derelict.opengl;
mixin glFreeFuncs!(GLVersion.gl40);

void glCheck() @nogc
{
	debug
	{
		import std.format;
		auto error = glGetError();
		assert(error == GL_NO_ERROR, format("OpenGL error: %d", error));
	}
	else
	{
		return;
	}
}