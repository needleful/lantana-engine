// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

import std.stdio;
import std.string;

import logic.scenes;
import lanlib.file.gltf2;
import lanlib.file.lgbt;
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

	File errLog = File("model_error.log", "w");
	auto lines = File(path, "r").byLine();
	foreach(ref line; lines) 
	{
		mem.wipe();
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
			binaryStore(outFile, results);
			debug
			{
				GLBAnimatedLoadResults validate = binaryLoad!GLBAnimatedLoadResults(outFile, mem);
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
			binaryStore(outFile, results);
			debug
			{
				GLBStaticLoadResults validate = binaryLoad!GLBStaticLoadResults(outFile, mem);
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
		writefln("--CONVERT %8s: %s => %s", type, inFile, outFile);
	}

	return 0;
}