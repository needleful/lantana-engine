// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.prolog_engine;

import std.file;
import std.stdio;

import swi.experimental;

struct PrologInterface
{
	string save_path;
	
	@disable this();

	this(string appName, string p_save_path, string p_startFile)
	{
		char*[] argv = [
			cast(char*) appName.ptr,
			cast(char*) "-g",
			cast(char*) "true",
			cast(char*) "-t",
			cast(char*) "halt",
			cast(char*) "-f",
			cast(char*) p_startFile.ptr
		];

		save_path = p_save_path;
		if(save_path.exists)
		{
			argv ~= [cast(char*) "-x", cast(char*) save_path];
		}

		if(!PL_initialise(cast(int) argv.length, argv.ptr))
		{
			throw new Exception("Failed to initialize Prolog runtime.");
		}
		else
		{
			writeln("++ Initialized SWI-Prolog");
		}
	}

	bool save()
	{
		Predicate qsave = Predicate("qsave_program", 1);
		assert(qsave.predicate);
		
		if(save_path.exists())
		{
			save_path.remove();
		}

		if(qsave(save_path) == TRUE)
		{
			writeln("Saved session");
			return true;
		}
		else
		{
			writeln("Failed to save session");
			return false;
		}
	}

	~this()
	{
		PL_halt(PL_toplevel() ? 0 : 1);
	}
}