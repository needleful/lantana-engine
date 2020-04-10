// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.dialog;

public final class Dialog
{
	import std.conv;
	import std.regex;

	alias Callback = void delegate(Dialog message);
	public string message;
	public float pauseTime;

	public Requirement[] requirements;
	public Effect[] effects;
	public Dialog[] responses;

	version(lantana_editor)
	{
		import lantana.types: ivec2;
		public ivec2 edit_position;
	}

	this(string p_message, float p_pause, Dialog[] p_responses)
	{
		pauseTime = p_pause;
		message = p_message;
		responses = p_responses;
	}

	string getTag()
	{
		import std.format;
		return format("%X", cast(void*)this);
	}

	public string getRequirements()
	{
		string s = "";
		foreach(req; requirements)
		{
			s ~= req.toString();
			if(req.next != Requirement.Next.None)
			{
				s ~= ' ';
			}
		}
		return s;
	}

	void setRequirements(const(string) req)
	{
		requirements = [];
		static auto rx = ctRegex!`(?P<key>\S*?)\s*(?P<op>[=<>!]+)\s*(?P<value>[\-\d\.]+?)\s*(?P<next>[,;]?)`;
		foreach(m; req.matchAll(rx))
		{
			if(m["key"].length == 0)
			{
				writefln("Missing key for requirement: %s", m.hit);
				continue;
			}

			Requirement.Op op;
			Requirement.Next next;
			float value = m["value"].to!float();

			switch(m["op"])
			{
				case "=":
					op = Requirement.Op.Equal;
					break;
				case "<":
					op = Requirement.Op.Less;
					break;
				case ">":
					op = Requirement.Op.Greater;
					break;
				case "<=":
					op = Requirement.Op.Leq;
					break;
				case ">=":
					op = Requirement.Op.Geq;
					break;
				case "!=":
					op = Requirement.Op.Neq;
					break;
				default:
					writefln("WARNING: unknown op '%s' in requirement: '%s'", m["op"], m.hit);
					op = Requirement.Op.Equal;
					break;
			}
			switch(m["next"])
			{
				case ";":
					next = Requirement.Next.Or;
					break;
				case ",":
					next = Requirement.Next.And;
					break;
				default:
					next = Requirement.Next.None;
					break;
			}

			requirements ~= Requirement(m["key"], op, value, next);
		}
	}

	public string getEffects()
	{
		string s = "";
		foreach(i, effect; effects)
		{
			s ~= effect.toString();
			if(i < effects.length - 1)
			{
				s ~= "; ";
			}
		}
		return s;
	}

	public void setEffects(string str)
	{
		effects = [];
		static auto rx = ctRegex!`(?P<key>\S*?)\s*(?P<op>[+\-*/:=]+?)\s*(?P<value>[\-\d\.]+)\s*;?`;

		foreach(m; str.matchAll(rx))
		{
			if(m["key"].length == 0)
			{
				writefln("Missing key for effect: %s", m.hit);
				continue;
			}

			Effect.Op op;
			float value = m["value"].to!float();

			switch(m["op"])
			{
				case "=":
				case ":=":
					op = Effect.Op.Set;
					break;
				case "+":
				case "+=":
					op = Effect.Op.Add;
					break;
				case "-":
				case "-=":
					op = Effect.Op.Subtract;
					break;
				case "*":
				case "*=":
					op = Effect.Op.Multiply;
					break;
				case "/":
				case "/=":
					op = Effect.Op.Divide;
					break;
				default:
					op = Effect.Op.Add;
					writefln("WARNING: unknown op '%s' in effect: '%s'", m["op"], m.hit);
					break;
			}

			effects ~= Effect(m["key"], op, value);
		}
	}
}

import std.format;

struct Requirement
{
	enum Op
	{
		Equal,
		Less,
		Greater,
		Neq,
		Leq,
		Geq
	}

	enum Next
	{
		Or,
		And,
		None
	}

	string key;
	float value;
	Op op;
	Next next;

	public this(string p_key, Op p_op, float p_value, Next p_next)
	{
		key = p_key;
		op = p_op;
		value = p_value;
		next = p_next;
	}

	public bool opCall(float test)
	{
		switch(op)
		{
			case Op.Equal:
				return test == value;
			case Op.Less:
				return test < value;
			case Op.Greater:
				return test > value;
			case Op.Geq:
				return test >= value;
			case Op.Leq:
				return test <= value;
			default:
				return false;
		}
	}

	public string toString()
	{
		string strOp, strNext;
		switch(op)
		{
			case Op.Equal:
				strOp = "=";
				break;
			case Op.Less:
				strOp = "<";
				break;
			case Op.Greater:
				strOp = ">";
				break;
			case Op.Neq:
				strOp = "!=";
				break;
			case Op.Leq:
				strOp = "<=";
				break;
			case Op.Geq:
				strOp = ">=";
				break;
			default:
				strOp = "=";
				writefln("WARNING: unknown requirement op: %s", op);
				break;
		}
		switch(next)
		{
			case Next.Or:
				strNext = ";";
				break;
			case Next.And:
				strNext = ",";
				break;
			case Next.None:
				strNext = "";
				break;
			default:
				strNext = ";";
				writefln("WARNING: unknown requirement continuation: %s", next);
				break;
		}

		return format("%s %s %s%s", key, strOp, value, strNext);
	}
}

struct Effect
{
	enum Op
	{
		// = or :=
		Set,
		// + or +=
		Add,
		// - or -=
		Subtract,
		// * or *=
		Multiply,
		// `/` or `/=`
		Divide
	}

	string key;
	Op op;
	float value;

	this(string p_key, Op p_op, float p_value)
	{
		key = p_key;
		op = p_op;
		value = p_value;
	}

	public string toString()
	{
		string strOp;
		switch(op)
		{
			case Op.Set:
				strOp = ":=";
				break;
			case Op.Add:
				strOp = "+";
				break;
			case Op.Subtract:
				strOp = "-";
				break;
			case Op.Multiply:
				strOp = "*";
				break;
			case Op.Divide:
				strOp = "/";
				break;
			default:
				writefln("WARNING: Unknown Effect Op: %s", op);
				break;
		}

		return format("%s %s %s", key, strOp, value);
	}
}

import std.stdio;
import sdlang;

import lantana.types : ivec2;

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

		map[key] = new Dialog(message, pause, []);
		auto req = d.getTagValue!string("requirements", "");
		map[key].setRequirements(req);
		auto eff = d.getTagValue!string("effects", "");
		map[key].setEffects(eff);

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
				new Tag(null, "requirements", [Value(d.getRequirements())]),
				new Tag(null, "effects", [Value(d.getEffects())]),
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
				new Tag(null, "requirements", [Value(d.getRequirements())]),
				new Tag(null, "effects", [Value(d.getEffects())]),
				new Tag(null, "responses", responses),
			]);
		}
	}

	file.add(new Tag(null, "start", [Value(p_dialog.getTag())], null, []));

	File output = File(p_file, "w");
	output.write(file.toSDLDocument());
}