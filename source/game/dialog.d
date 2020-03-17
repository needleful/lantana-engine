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
	public Dialog[] responses;

	this(string p_message, float p_pause, Dialog[] p_responses, string p_date = "")
	{
		pauseTime = p_pause;
		message = p_message;
		responses = p_responses;
		date = p_date;
	}
}

import std.stdio;
import sdlang;

public Dialog loadDialog(string p_file)
{
	Dialog[string] map;

	Tag file = parseFile(p_file);

	string start = file.expectTagValue!string("start");
	writeln("start: ",start);

	foreach(d; file.tags["dialog"])
	{
		string key = d.expectValue!string();
		string message = d.expectTagValue!string("message");
		float pause = d.getTagValue!float("pause", 0.75);
		string date = d.getTagValue!string("date", "");

		map[key] = new Dialog(message, pause, [], date);
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
			dialog.responses ~= map[resp.get!string()];
		}
	}

	return map[start];
}

public void storeDialog(string p_file, Dialog p_dialog)
{
	string getKey(Dialog p_dl)
	{
		import std.format;
		return format("%X", (cast(long) cast(void*)p_dl) & 0xFFFFF);
	}

	void addToMap(ref Dialog[string] p_map, Dialog p_dl)
	{
		string key = getKey(p_dl);

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
			string respKey = getKey(resp);
			assert(respKey in map);
			responses ~= Value(respKey);
		}

		Tag t = new Tag(file, null, "dialog", [Value(key)], null, 
		[
			new Tag(null, "message", [Value(d.message)]),
			new Tag(null, "pause", [Value(d.pauseTime)]),
			new Tag(null, "date", [Value(d.date)]),
			new Tag(null, "responses", responses)
		]);
		//file.add(t);
	}

	file.add(new Tag(null, "start", [Value(getKey(p_dialog))], null, []));

	File output = File(p_file, "w");
	output.write(file.toSDLDocument());
}

public final Dialog testDialog()
{
	Dialog start = new Dialog("thinking of you", 2, [], "3:05 AM");

	Dialog justSaying = 
		new Dialog("i just wanted to say", 1,[
			new Dialog("I love you.", 0.8, [

			]),
			new Dialog("there was a problem", 2, [

			])
		]);

	start.responses = [
		new Dialog("hey", 0.3, 
		[
			
		], "2:41 PM"),

		new Dialog("Hi Boto", 0.3, 
		[
			justSaying,
			new Dialog("how are you?", 2, 
			[
				new Dialog("wait you can't send replies when i;m in space", 4, 
				[
					new Dialog("god dammit", 1, 
					[

					]),
					new Dialog("its fine.", 2, [justSaying])
				])
			])
		], "2:41 PM"),
		new Dialog("the ship exploded.", 0.3,
		[
			new Dialog("it fucking exploded", 0.6,
			[
			])
		], "2:41 PM"),
	];

	return start;
}