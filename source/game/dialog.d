// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.dialog;

public final class Dialog
{
	alias Callback = void delegate(Dialog message);
	public string message;
	public float pauseTime;
	public string date;
	public string requirements;
	public string effects;
	public Dialog[] responses;

	version(lantana_editor)
	{
		import lanlib.types: ivec2;
		public ivec2 edit_position;
	}

	this(string p_message, float p_pause, Dialog[] p_responses, string p_date = "")
	{
		pauseTime = p_pause;
		message = p_message;
		responses = p_responses;
		date = p_date;
	}

	string getTag()
	{
		import std.format;
		return format("%X", cast(void*)this);
	}
}

import std.stdio;
import sdlang;

import lanlib.types : ivec2;

public Dialog[string] loadDialog(string p_file, out string p_start)
{
	Dialog[string] map;

	Tag file = parseFile(p_file);

	string start = file.expectTagValue!string("start");
	p_start = start;

	foreach(d; file.tags["dialog"])
	{
		string key = d.expectValue!string();
		string message = d.expectTagValue!string("message");
		float pause = d.getTagValue!float("pause", 0.75);
		string date = d.getTagValue!string("date", "");

		map[key] = new Dialog(message, pause, [], date);

		map[key].requirements = d.getTagValue!string("requirements", "");
		map[key].effects = d.getTagValue!string("effects", "");

		version(lantana_editor)
		{
			Value[] pos = d.getTagValues("edit_position");
			if(pos != null)
			{
				map[key].edit_position = ivec2(pos[0].get!int(), pos[1].get!int());
			}
		}
	}

	foreach(d; file.tags["dialog"])
	{
		Dialog dialog = map[d.expectValue!string()];
		Value[] responses = d.getTagValues("responses");

		if(responses == null)
		{
			continue;
		}

		dialog.responses.reserve(responses.length);
		foreach(resp; responses)
		{
			string key = resp.get!string();
			if(key !in map)
			{
				writefln("Warning: missing response %s", key);
			}
			dialog.responses ~= map[key];
		}
	}

	return map;
}

public void storeDialog(string p_file, Dialog p_dialog)
{
	void addToMap(ref Dialog[string] p_map, Dialog p_dl)
	{
		string key = p_dl.getTag();

		if(key in p_map)
			return;

		p_map[key] = p_dl;

		foreach(r; p_dl.responses)
			addToMap(p_map, r);
	}

	Dialog[string] map;
	addToMap(map, p_dialog);

	Tag file = new Tag();

	foreach(string key, Dialog value; map)
	{
		Dialog d = value;
		Value[] responses;
		responses.reserve(d.responses.length);

		foreach(resp; d.responses)
		{
			string respKey = resp.getTag();
			assert(respKey in map);
			responses ~= Value(respKey);
		}

		version(lantana_editor)
		{
			Tag t = new Tag(file, null, "dialog", [Value(key)], null, 
			[
				new Tag(null, "message", [Value(d.message)]),
				new Tag(null, "pause", [Value(d.pauseTime)]),
				new Tag(null, "date", [Value(d.date)]),
				new Tag(null, "requirements", d.requirements),
				new Tag(null, "effects", d.effects),
				new Tag(null, "responses", responses),
				new Tag(null, "edit_position", [Value(d.edit_position.x), Value(d.edit_position.y)])
			]);
		}
		else
		{
			Tag t = new Tag(file, null, "dialog", [Value(key)], null, 
			[
				new Tag(null, "message", [Value(d.message)]),
				new Tag(null, "pause", [Value(d.pauseTime)]),
				new Tag(null, "date", [Value(d.date)]),
				new Tag(null, "requirements", d.requirements),
				new Tag(null, "effects", d.effects),
				new Tag(null, "responses", responses),
			]);
		}
	}

	file.add(new Tag(null, "start", [Value(p_dialog.getTag())], null, []));

	File output = File(p_file, "w");
	output.write(file.toSDLDocument());
}