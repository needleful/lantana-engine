// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.prolog_engine;

import swi.experimental;
import swi.prolog;
import std.stdio;

struct PrologInterface
{
	import std.file;
	Module engine;
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

		init_module();
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

	/+++++++++++++++++++++++++++++++++++++++++++++
	+          Engine Module Predicates          +
	+                                            +
	+ Foreign predicates that can be called from +
	+ Prolog. Must match the ForeignPredicate or +
	+ ForeignPredicateVariadic templates defined +
	+ in the module `swi.experimental`           +
	+                                            +
	+ The predicates are all avaliable in the    +
	+ "engine" module in Prolog                  +
	++++++++++++++++++++++++++++++++++++++++++++++/

	void init_module()
	{
		engine = Module("engine");
		engine.addPredicates!(dummy)();
	}

	@variadic(2)
	static extern(System) foreign_t dummy(term_t t0, int arity, void* context) @nogc nothrow
	{
		printf("engine:dummy/%d(", arity);

		Term.print(t0);
		printf(", ");
		Term.print(t0+1);
		puts(")");

		return TRUE;
	}
}