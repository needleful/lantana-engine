// An experimental interface on top of swi.prolog
// Written by Devin Hastings aka needleful
// Licensed under GPL v3.0

module swi.experimental;

import std.stdio;
import std.string;

import swi.prolog;

struct Predicate
{
	predicate_t predicate;
	module_t m_module;
	ulong arity;

	this(string p_name, uint p_arity, string p_module = "") @nogc nothrow
	{
		predicate = PL_predicate(cast(char*)p_name.ptr, p_arity, cast(char*) p_module.ptr);
		PL_predicate_info(predicate, null, &arity, &m_module);
	}

	int opCall(Term p_term, int p_debug = PL_Q_NORMAL) @nogc nothrow
	{
		return PL_call_predicate(m_module, p_debug, predicate, p_term.term);
	}

	int opCall(T)(T p_value, int p_debug = PL_Q_NORMAL) @nogc nothrow
		if(!is(T == Term))
	{
		return opCall(Term(p_value), p_debug);
	}

	Query open(Term p_term, int p_debug = PL_Q_NORMAL) @nogc nothrow
	{
		return Query(this, p_term, p_debug);
	}

	Query open(T)(T p_value, int p_debug = PL_Q_NORMAL) @nogc nothrow
		if(!is(T == Term))
	{
		return Query(this, Term(p_value), p_debug);
	}
}

struct Query
{
	qid_t id;

	this(ref Predicate p, Term t, int p_debug = PL_Q_NORMAL) @nogc nothrow
	{
		id = PL_open_query(p.m_module, p_debug, p.predicate, t.term);
	}

	bool next() @nogc nothrow
	{
		return PL_next_solution(id) == TRUE;
	}

	bool cut() @nogc nothrow
	{
		return PL_cut_query(id) == TRUE;
	}

	bool close() @nogc nothrow
	{
		return PL_close_query(id) == TRUE;
	}
}

struct Term
{
	term_t term;

	static Term variable() @nogc nothrow
	{
		Term t;
		t.term = PL_new_term_ref();
		PL_put_variable(t.term);
		return t;
	}

	static Term empty() @nogc nothrow
	{
		Term t;
		t.term = PL_new_term_ref();
		return t;
	}

	this(string s) @nogc nothrow
	{
		term = PL_new_term_ref();
		PL_put_atom_nchars(term, s.length, cast(char*) s.ptr);
	}

	this(char[] c) @nogc nothrow
	{
		term = PL_new_term_ref();
		PL_put_atom_nchars(term, c.length, c.ptr);
	}

	this(char* c) @nogc nothrow
	{
		term = PL_new_term_ref();
		PL_put_atom_chars(term, c);
	}

	this(long i) @nogc nothrow
	{
		term = PL_new_term_ref();
		PL_put_integer(term, i);
	}

	this(double f) @nogc nothrow
	{
		term = PL_new_term_ref();
		PL_put_float(term, f);
	}

	this(void* p) @nogc nothrow
	{
		term = PL_new_term_ref();
		PL_put_pointer(term, p);
	}

	// Assignment

	void opAssign(string s) @nogc nothrow
	{
		PL_put_atom_nchars(term, s.length, cast(char*) s.ptr);
	}

	void opAssign(char[] c) @nogc nothrow
	{
		PL_put_atom_nchars(term, c.length, c.ptr);
	}

	void opAssign(char* c) @nogc nothrow
	{
		PL_put_atom_chars(term, c);
	}

	void opAssign(long i) @nogc nothrow
	{
		PL_put_integer(term, i);
	}

	void opAssign(double f) @nogc nothrow
	{
		PL_put_float(term, f);
	}

	void opAssign(void* p) @nogc nothrow
	{
		PL_put_pointer(term, p);
	}

	static void print(term_t t) @nogc nothrow
	{
		import std.stdio;
		switch(PL_term_type(t))
		{
			case PL_VARIABLE:
				printf("_Var");
				break;
			case PL_ATOM:
				size_t size;
				char* text;
				PL_get_atom_nchars(t, &size, &text);
				printf(text);
				break;
			case PL_STRING:
				size_t size;
				char* text;
				PL_get_string_chars(t, &text, &size);
				printf("\"%s\"", text);
				break;
			case PL_SHORT:
			case PL_INT:
			case PL_LONG:
			case PL_INTEGER:
			case PL_INTPTR:
			case PL_INT64:
				long l;
				if(PL_get_int64(t, &l))
				{
					printf("%d", l);
					break;
				}
				else
				{
					printf("<big int>");
					break;
				}
			case PL_DOUBLE:
			case PL_FLOAT:
				double d;
				if(PL_get_float(t, &d))
				{
					printf("%f", d);
					break;
				}
				else
				{
					printf("<big float>");
					break;
				}

			case PL_TERM:
				size_t arity;
				atom_t name;
				PL_get_name_arity_sz(t, &name, &arity);
				printf("%s/%d(", PL_atom_chars(name), arity);
				term_t arg;
				for(size_t i = 1; i <= arity; i++)
				{
					PL_get_arg_sz(i, t, arg);
					if(i == 1)
					{
						Term.print(arg);
					}
					else
					{
						printf(", ");
						Term.print(arg);
					}
				}
				printf(")");
				break;
			case PL_NIL:
				printf( "nil");
				break;
			case PL_BLOB:
				printf( "blob");
				break;
			case PL_LIST_PAIR:
				printf( "list pair");
				break;
			case PL_FUNCTOR:
				printf( "functor");
				break;
			case PL_LIST:
				printf( "list");
				break;
			case PL_CHARS:
				printf( "chars");
				break;
			case PL_POINTER:
				printf( "pointer");
				break;
			case PL_CODE_LIST:
				printf( "code list");
				break;
			case PL_CHAR_LIST:
				printf( "char list");
				break;
			case PL_BOOL:
				int i;
				PL_get_bool(t, &i);
				printf( i == TRUE? "true" : "false");
				break;
			case PL_FUNCTOR_CHARS:
				printf( "functor chars");
				break;
			case _PL_PREDICATE_INDICATOR:
				printf( "precicate indicator");
				break;
			case PL_NCHARS:
			case PL_UTF8_CHARS:
			case PL_UTF8_STRING:
			case PL_NUTF8_CHARS:
			case PL_NUTF8_CODES:
			case PL_NUTF8_STRING:
			case PL_NWCHARS:
			case PL_NWCODES:
			case PL_MBCHARS:
			case PL_MBCODES:
			case PL_MBSTRING:
				printf( "some sorta string");
				break;
			case PL_CHAR:
			case PL_CODE:
			case PL_BYTE:
				printf( "char/byte");
				break;
			case PL_PARTIAL_LIST:
			case PL_CYCLIC_TERM:
				printf( "list");
				break;
			case PL_NOT_A_LIST:
				printf( "not a list");
				break;
			case PL_DICT:
				printf( "dict");
				break;
			default:
				printf( "<??>");
				break;
		}
	}
}

struct Module
{
	import std.format;
	import std.traits: isFunction, arity, hasUDA, getUDAs;

	string nameString;
	atom_t name;
	module_t m_module;

	/// Find or create a module with this name
	this(string p_name) @nogc nothrow
	{
		nameString = p_name;
		name = PL_new_atom_nchars(p_name.length, cast(const(char*)) p_name.ptr);
		m_module = PL_new_module(name);
	}

	/// Add a foreign predicate to this module
	bool addPredicate(alias func)(string p_name = __traits(identifier, func), short p_flags = 0)
		if(isFunction!func)
	{
		enum ar = arity!func;

		return PL_register_foreign_in_module(
			nameString.toStringz(),
			p_name.toStringz(),
			ar,
			checkForeignArity!ar(&func),
			p_flags
		) == TRUE;
	}

	void addPredicates(funcs...)()
	{
		PL_extension[funcs.length + 1] extensions;
		static foreach(int i, f; funcs)
		{{
			enum fname = __traits(identifier, f);
			static assert(isFunction!f, format("%s is not a function.", fname));

			short flags;
			static if(!foreignIsVariadic!(arity!f)(&f))
			{
				enum ar = arity!f;
			}
			else
			{
				flags = PL_FA_VARARGS;
				static if(hasUDA!(f, variadic))
				{
					enum ar = getUDAs!(f, variadic)[0].arity;
				}
				else
				{
					pragma(msg, format("WARNING: variadic function %s does not have the @variadic attribute", fname));
					enum ar = 1;
				}
			}

			extensions[i].predicate_name = fname;
			extensions[i].arity = ar;
			extensions[i].function_ = checkForeignArity!ar(&f);
			extensions[i].flags = flags;
		}}

		// Last value is null
		extensions[$-1].predicate_name = null;
		extensions[$-1].arity = 0;
		extensions[$-1].function_ = null;
		extensions[$-1].flags = 0;

		PL_register_extensions_in_module(nameString.toStringz(), extensions.ptr);
	}
}

struct variadic
{
	uint arity;

	this(uint p_arity)
	{
		arity = p_arity;
	}
}

/// Foreign predicate with a fixed arity
template ForeignPredicate(uint Arity)
{
	import std.meta: Repeat;
	alias ForeignPredicate = static extern(System) foreign_t function(Repeat!(Arity, term_t)) @nogc nothrow; 
}

/// Variadic foreign predicate
alias ForeignPredicateVariadic = static extern(System) foreign_t function(term_t, int, void*) @nogc nothrow;

private bool foreignIsVariadic(uint Arity)(ForeignPredicate!Arity func)
{
	return false;
}

private bool foreignIsVariadic(uint Arity)(ForeignPredicateVariadic func)
{
	return true;
}

private void* checkForeignArity(uint Arity)(ForeignPredicate!Arity func)
{
	return cast(void*) func;
}

private void* checkForeignArity(uint Arity)(ForeignPredicateVariadic func)
{
	return cast(void*) func;
}