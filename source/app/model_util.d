// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

import std.stdio;
import std.string;

import lanlib.file.gltf2;
import lanlib.file.lnb;
import lanlib.util.memory;

struct Friend
{
	string name;
	int age;

	this(string p_name, int p_age)
	{
		name = p_name;
		age = p_age;
	}
}

struct Boy
{
	string[] favoriteFoods;
	Friend[] friends;
	string name;
	int age;
}

int main(string[] args)
{
	if(args.length != 2)
	{
		writeln("Need one argument: file containing tab-separated input and output files");
	}

	//basic tests of the memory functions
	{
		ubyte[] data;
		ulong start;
		uint[] ints = data.addSpace!uint(24, start);
		ints[0] = 4;

		assert(data.length == uint.sizeof*24);
		assert(data[0] == 4);
		assert(start == 0);

		string h = "Hello, world";
		char[] charming = data.addSpace!char(h.length, start);

		charming.readData(h);

		assert(start == uint.sizeof*24);
		assert(charming == "Hello, world");
	}

	// More advanced tests of LNBDescriptor
	{
		Boy boy;
		with(boy)
		{
			age = 14;
			name = "Steven";
			friends = [
				Friend("Garnet", 5700),
				Friend("Pearl", 4400),
				Friend("Amethyst", 120),
				Friend("Connie", 12)
			];
			favoriteFoods = [
				"pizza",
				"burgers",
				"seafood"
			];
		}

		ubyte[] data;
		auto serialBoy = LNBDescriptor!Boy(boy, data);

		auto deserialBoy = serialBoy.getData(data);
		if(boy != deserialBoy)
		{
			writeln("EXPECTED: ", boy);
			writeln("ACTUAL: ", deserialBoy);
			writeln("SERIALIZED: ", serialBoy);
			writeln("BUFFER: ", data);

			return -1;
		}
	}

	string path = args[1];
	writeln("Opening: ", path);

	BaseRegion mem = BaseRegion(MAX_MEMORY/4);

	File errLog = File("model_error.log", "w");
	auto lines = File(path, "r").byLine();
	foreach(ref line; lines) 
	{
		if(line.length == 0 || line[0] == '#')
		{
			// A comment or empty, ignore
			continue;
		}
		string[] fields = cast(string[]) line.split("\t");

		assert(fields.length == 3);

		string type = fields[0];
		string inFile = fields[1];
		string outFile = fields[2];

		assert(type == "anim" || type == "static");

		if(type == "anim")
		{
			GLBAnimatedLoadResults results = glbLoad!true(inFile, mem);
			lnbStore!GLBAnimatedLoadResults(outFile, results);
			debug
			{
				GLBAnimatedLoadResults validate = lnbLoad!GLBAnimatedLoadResults(outFile, mem);
				if(validate != results)
				{
					errLog.writeln("======\nFALURE: validation returned differences for ", inFile);
					errLog.writeln("GLB FILE: \n", results);
					errLog.writeln("LNB FILE: \n", validate);
					writeln("--FALURE: validation returned differences for ", inFile);
					continue;
				}
			}
		}
		else if(type == "static")
		{
			GLBStaticLoadResults results = glbLoad!false(inFile, mem);
			lnbStore!GLBStaticLoadResults(outFile, results);
			debug
			{
				GLBStaticLoadResults validate = lnbLoad!GLBStaticLoadResults(outFile, mem);
				if(validate != results)
				{
					errLog.writeln("FALURE: validation returned differences for ", inFile);
					errLog.writeln("GLB FILE: \n", results);
					errLog.writeln("LNB FILE: \n", validate);
					writeln("--FALURE: validation returned differences for ", inFile);
					continue;
				}
			}
		}
		writefln("--CONVERT %8s: %s => %s", type, inFile, outFile);
		mem.wipe();
	}

	return 0;
}