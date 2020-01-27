// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

import std.stdio;
import std.string;

import lanlib.file.gltf2;
import lanlib.file.lnb;
import lanlib.util.memory;


int main(string[] args)
{
	if(args.length != 2)
	{
		writeln("Need one argument: file containing tab-separated input and output files");
	}

	string path = args[1];
	writeln("Opening: ", path);

	BaseRegion mem = BaseRegion(MAX_MEMORY/4);

	auto lines = File(path, "r").byLine();
	foreach(ref line; lines) 
	{
		if(line.length == 0 || line[0] == '#')
		{
			// A comment or empty, ignore
			break;
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
		}
		else if(type == "static")
		{
			GLBStaticLoadResults results = glbLoad!false(inFile, mem);
			lnbStore!GLBStaticLoadResults(outFile, results);
		}
		writefln("--CONVERT %8s: %s => %s", type, inFile, outFile);
		mem.wipe();
	}

	return 0;
}