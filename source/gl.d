// Lantana
// gl.d
// Licensed under GPL v3.0

/// Module defining OpenGL functionality
module lantana.gl;

public import derelict.opengl;
mixin glFreeFuncs!(GLVersion.gl43);