// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.render.lights;

import lantana.render.gl;
import lantana.render.textures;
import lantana.types.core;
import lantana.types.memory;

struct LightPalette
{
	Texture!Color palette;
	
	public this(string p_palette_file, ref Region p_alloc)
	{
		palette = Texture!Color(p_palette_file, p_alloc, Filter(TexFilter.Linear));
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	}
}