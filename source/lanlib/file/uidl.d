// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.file.uidl;

import std.algorithm;
import std.stdio;

import sdlang;

import ui;

struct WidgetName
{
	string name;

	this(string p_name)
	{
		this.name = name;
	}
}

enum Optional;
enum Ignored;

enum ParamList;

struct Param
{
	string name;
	short index;

	this(short p_index)
	{
		index = p_index;
		name = "";
	}

	this(string p_name)
	{
		name = p_name;
		index = -1;
	}
}

struct Attrib
{
	string name;

	this(string p_name)
	{
		name = p_name;
	}
}

void loadFile(UIRenderer p_renderer, string p_file)
{
	writeln("Loading file: ", p_file);
	FontId[string] fonts;

	Tag root = parseFile(p_file);

	auto fontTag = root.getTag("fonts");

	foreach(ref fontVal; fontTag.all.tags)
	{
		assert(fontVal.values.length == 2, "Fonts have two values: file and size");
		string file = fontVal.values[0].get!string();
		int size = fontVal.values[1].get!int();

		fonts[fontVal.getFullName.toString()] = p_renderer.loadFont(file, cast(ubyte) size);
	}


	writeln("Finished loading ", p_file);
} 