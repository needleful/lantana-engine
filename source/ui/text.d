// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module ui.text;

import std.exception;
import std.string: toStringz;

import lanlib.math.vector: iVec2;

import derelict.freetype;

/// Text box
struct SimpleTextBox
{
	iVec2 pos;
	string text;
}

/// Text system
struct TextRenderer
{
	private 
	{
		FT_Library library;
		FT_Face default_face;
		struct GlyphData
		{

		}
	}
	this(string default_font, ushort default_font_size)
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
		FT_Set_Pixel_Sizes(default_face, 0, default_font_size);
	}

	~this()
	{
		FT_Done_Face(default_face);
		FT_Done_FreeType(library);
	}
}