// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module ui.text;

import std.exception;
import std.string: toStringz;

import derelict.freetype;

/**
 * Text system (should only have one)
 */
struct TextRenderer
{
	private FT_Library library;
	private FT_Face default_face;
	this(string default_font)
	{
		DerelictFT.load();
		if(FT_Init_FreeType(&library))
		{
			throw new Exception("Could not initialize freetype library");
		}
		if(FT_New_Face(library, default_font.toStringz(), 0L, &default_face))
		{
			throw new Exception("Count not load default FreeType font");
		}
	}

	~this()
	{
		FT_Done_Face(default_face);
		FT_Done_FreeType(library);
	}
}