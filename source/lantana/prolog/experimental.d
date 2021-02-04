// An experimental interface on top of swi.prolog
// Written by Devin Hastings aka needleful
// Licensed under GPL v3.0

module lantana.prolog.experimental;

public import lantana.prolog.swi;

import std.format;
import std.stdio;
import std.string;

struct Predicate
{
	predicate_t predicate;
	module_t m_module;
	size_t arity;

	this(string p_name, size_t p_arity, string p_module = "") @nogc nothrow
	{
		predicate = PL_predicate(cast(char*)p_name.ptr, cast(int) p_arity, cast(char*) p_module.ptr);
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

	int opCall(T, A...)(T value, A values) @nogc nothrow
		if(!is(T == Term) && values.length > 0)
	{
		enum len = values.length + 1;
		Term args = Term.args(len);
		args = value;
		foreach(i, v; values)
		{
			Term t = Term.of(args.term + i + 1);
			t = v;
		}
		return opCall(args);
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
	alias term this;

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

	static Term args(int count) @nogc nothrow
	{
		Term t;
		t.term = PL_new_term_refs(count);
		return t;
	}

	static Term nil() @nogc nothrow
	{
		Term t;
		t.term = PL_new_term_ref();
		PL_put_nil(t);
		return t;
	}

	static Term copy(term_t t2) @nogc nothrow
	{
		Term t;
		t.term = PL_copy_term_ref(t2);
		return t;
	}

	static Term of(term_t t2) @nogc nothrow
	{
		Term t;
		t.term = t2;
		return t;
	}

	static bool tryParse(string s, out Term result) @nogc nothrow
	{
		result.overwrite(Term.empty());
		return PL_put_term_from_chars(result.term, REP_UTF8, s.length, s.ptr) == TRUE;
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

	this(Term t) @nogc nothrow
	{
		term = PL_copy_term_ref(t.term);
	}

	void overwrite(term_t p_term) @nogc nothrow
	{
		term = p_term;
	}

	void overwrite(Term rhs) @nogc nothrow
	{
		term = rhs.term;
	}

	// Assignment

	void opAssign(ref Term rhs) @nogc nothrow
	{
		PL_put_term(term, rhs.term);
	}

	void opAssign(Term rhs) @nogc nothrow
	{
		PL_put_term(term, rhs.term);
	}

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

	void opOpAssign(string op)(Term rhs)
		if(op == "~")
	{
		PL_unify_list(term, rhs, term);
	}

	void addHead(Term rhs)
	{
		PL_unify_list(term, rhs, term);
	}

	string toString()
	{
		import std.conv;
		import std.format;
		switch(PL_term_type(term))
		{
			case PL_VARIABLE:
				return "_Var";
			case PL_ATOM:
				size_t size;
				char* text;
				PL_get_atom_nchars(term, &size, &text);
				return format("'%s'", to!string(text));
			case PL_STRING:
				size_t size;
				char* text;
				PL_get_string_chars(term, &text, &size);
				return format("\"%s\"", to!string(text));
			case PL_SHORT:
			case PL_INT:
			case PL_LONG:
			case PL_INTEGER:
			case PL_INTPTR:
			case PL_INT64:
				long l;
				if(PL_get_int64(term, &l))
				{
					return format("%d", cast(int) l);
				}
				else
				{
					return format("<big int>");
				}
			case PL_DOUBLE:
			case PL_FLOAT:
				double d;
				if(PL_get_float(term, &d))
				{
					return format("%f", d);
				}
				else
				{
					return "<big float>";
				}

			case PL_TERM:
				size_t arity;
				atom_t name;
				PL_get_name_arity_sz(term, &name, &arity);
				string s = format("%s(", to!string(PL_atom_chars(name)));
				string terms;
				Term arg = Term.empty();
				for(size_t i = 1; i <= arity; i++)
				{
					PL_get_arg_sz(i, term, arg.term);
					if(i == 1)
					{
						terms ~= arg.toString();
					}
					else
					{
						terms ~= ", " ~ arg.toString();
					}
				}
				return s ~ terms ~ ")";
			case PL_NIL:
				return "nil";
			case PL_BLOB:
				return "blob";
			case PL_FUNCTOR:
				return "functor";
			case PL_LIST:
			case PL_LIST_PAIR:
				string s = "[";
				Term list = Term.copy(term);
				Term head = Term.empty();
				int i = 0;
				while(PL_get_list(list, head, list))
				{
					if(i == 0)
					{
						s ~= head.toString();
					}
					else
					{
						s ~= ", " ~ head.toString();
					}
					i++;
				}
				return s ~ "]";
			case PL_CHARS:
				return "chars";
			case PL_POINTER:
				return "pointer";
			case PL_CODE_LIST:
				return "code list";
			case PL_CHAR_LIST:
				return "char list";
			case PL_BOOL:
				int i;
				PL_get_bool(term, &i);
				return i == TRUE? "true" : "false";
			case PL_FUNCTOR_CHARS:
				return( "functor chars");
			case _PL_PREDICATE_INDICATOR:
				return "precicate indicator";
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
				return "some sorta string";
			case PL_CHAR:
			case PL_CODE:
			case PL_BYTE:
				return "char/byte";
			case PL_PARTIAL_LIST:
			case PL_CYCLIC_TERM:
				return "list";
			case PL_NOT_A_LIST:
				return "not a list";
			case PL_DICT:
				return "{dict}";
			default:
				return "<??>";
		}
	}
}

template typeToPL(T)
{
	static if(is(T == atom_t))
		enum typeToPL = PL_ATOM;
	else static if(is(T == int) || is(T == long))
		enum typeToPL = PL_INTEGER;
	else static if(is(T == float) || is(T == double))
		enum typeToPL = PL_FLOAT;
	else static if(is(T == char*))
		enum typeToPL = PL_STRING;
	else static if(is(T == typeof(null)))
		enum typeToPL = PL_NIL;
	else static if(is(T == functor_t))
		enum typeToPL = PL_FUNCTOR;
	else static if(is(T == int))
		enum typeToPL = PL_INTEGER;
	else static if(is(T== void*))
		enum typeToPL = PL_POINTER;
	else
		static assert(false, format("No support for PL type of %s", T.stringof));
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
	alias ForeignPredicate = extern(System) foreign_t function(Repeat!(Arity, term_t)) nothrow; 
}

/// Variadic foreign predicate
alias ForeignPredicateVariadic = extern(System) foreign_t function(term_t, int, void*) nothrow;

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