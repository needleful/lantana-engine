// A port of SWI-Prolog.h
// Ported by Devin Hastings
/+ Original copyright notice:
    Part of SWI-Prolog

    Author:        Jan Wielemaker
    E-mail:        J.Wielemaker@vu.nl
    WWW:           http://www.swi-prolog.org
    Copyright (c)  2008-2017, University of Amsterdam
                              VU University Amsterdam
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions
    are met:

    1. Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.

    2. Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in
       the documentation and/or other materials provided with the
       distribution.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
    COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
+/

module lantana.prolog.swi;

version(Windows)
{
	import core.sys.windows.windows;
}
import std.stdint: intptr_t, uintptr_t, int64_t, uint64_t;


extern(System) @nogc nothrow:

enum PLVERSION = 80003;

// Prolog atom
alias atom_t = uintptr_t;
// Name/arity pair
alias functor_t = uintptr_t;
// Prolog moduleName
alias module_t = void*;
// Prolog procedure
alias predicate_t = void*;
// Prolog recorded term
alias record_t = void*;

// Opaque term handle
alias term_t = uintptr_t;

// Opaque query handle
alias qid_t = uintptr_t;
// Opaque foreign context handle
alias PL_fid_t = uintptr_t;
// Non-deterministic control arg
alias control_t = void*;
// Opaque engine handle
alias PL_engine_t = void*;

// Same as a worod
alias PL_atomic_t = uintptr_t;
// Return type of foreign functions
alias foreign_t = uintptr_t;
// Prolog wide character
alias pl_wchar_t = wchar;
// Passing functions as void*
alias pl_function_t = void*;

alias fid_t = PL_fid_t;

union term_value_t
{
	int64_t i;
	double f;
	char* s;
	atom_t a;
	struct term
	{
		atom_t name;
		size_t arity;
	}
	term t;
}

enum
{
	FALSE = 0,
	TRUE = 1
}

// Term-type constants
enum
{
/+ PL_unify_term() arguments +/

	// Nothing
	PL_VARIABLE  = 1,
	// Const char*
	PL_ATOM      = 2,
	// int
	PL_INTEGER   = 3,
	// double
	PL_FLOAT     = 4,
	// const char*
	PL_STRING    = 5,

	PL_TERM      = 6,
	// The constant []
	PL_NIL       = 7,
	// non-atom blob
	PL_BLOB      = 8,
	// [_|_] term
	PL_LIST_PAIR = 9,

/+ PL_unify_term() +/

	// fuctor_t, arg ...
	PL_FUNCTOR = 10,
	// length, arg ...
	PL_LIST    = 11,
	// const char*
	PL_CHARS   = 12,
	// void*
	PL_POINTER = 13,

/+ PlArg::PlArg(text, type) +/

	// [ascii...]
	PL_CODE_LIST = 14,
	// [h,e,l,l,o]
	PL_CHAR_LIST = 15,
	// PL_set_prolog_flag()
	PL_BOOL      = 16,
	// PL_unify_term()
	PL_FUNCTOR_CHARS        = 17,
	// predicate_t (Procedure)
	_PL_PREDICATE_INDICATOR = 18,
	// short
	PL_SHORT  = 19,
	// int
	PL_INT    = 20,
	// long
	PL_LONG   = 21,
	// double
	PL_DOUBLE = 22,
	// size_t, const char*
	PL_NCHARS = 23,
	// const char*
	PL_UTF8_CHARS   = 24,
	// const char*
	PL_UTF8_STRING  = 25,
	// int64
	PL_INT64        = 26,
	// size_t, const char*
	PL_NUTF8_CHARS  = 27,
	// size_t, const char*
	PL_NUTF8_CODES  = 29,
	// size_t, const char*
	PL_NUTF8_STRING = 30,
	// size_t, const wchar*
	PL_NWCHARS  = 31,
	// size_t, const wchar*
	PL_NWCODES  = 32,
	// size_t, const wchar*
	PL_NWSTRING = 33,
	// const char*
	PL_MBCHARS  = 34,
	// const char*
	PL_MBCODES  = 35,
	// const char*
	PL_MBSTRING = 36,
	// intptr_t
	PL_INTPTR = 37,
	// int*
	PL_CHAR   = 38,
	// int*
	PL_CODE   = 39,
	// int*
	PL_BYTE   = 40,

/+ PL_skip_list() +/

	// a partial list
	PL_PARTIAL_LIST = 41,
	// a cyclic list/term
	PL_CYCLIC_TERM  = 42,
	// Object is not a list
	PL_NOT_A_LIST   = 43,

/+ dicts +/
	PL_DICT = 44,
}

/++
	Or'ed flags for PL_set_prolog_flag()
	MUST fit into a short int
++/
enum : ushort
{
	// Read-only prolog flag
	FF_READONLY = 0x1000,
	// Keep prolog flag if already set
	FF_KEEP     = 0x2000,
	// Fail if flag is non-existent
	FF_NOCREATE = 0x4000,
	// Force setting, overwrite READONLY
	FF_FORCE    = 0x8000,
	FF_MASK     = 0xF000,
}

enum
{
	PL_FIRST_CALL = 0,
	deprecated PL_CUTTED = 1,
	PL_PRUNED = 1,
	PL_REDO = 2
}

	/++++++++++++++++++++++++++++++++
	+ Non-deterministic call/return +
	+++++++++++++++++++++++++++++++++/

export foreign_t _PL_retry(intptr_t);
export foreign_t _PL_retry_address(void*);

export int         PL_foreign_control(control_t);
export intptr_t    PL_foreign_context(control_t);
export void*       PL_foreign_context_address(control_t);
export predicate_t PL_foreign_context_predicate(control_t);


	/+++++++++++++++++++++++++++++
	+    Registering foreigns    +
	++++++++++++++++++++++++++++++/

struct PL_extension
{
	// Name of the predicate
	const(char)* predicate_name;
	// Arity of the predicate
	short arity;
	// Implementing functions
	// Note: named 'function' in C, but that's reserved in D
	pl_function_t function_;
	// Or of PL_FA_...
	short flags;
}

enum
{
	// Foreign cannot be traced
	PL_FA_NOTRACE          = 0x01,
	// Foreign is moduleName transparent
	PL_FA_TRANSPARENT      = 0x02,
	// Foreign is non-deterministic
	PL_FA_NONDETERMINISTIC = 0x04,
	// Call using t0, ac, ctx
	PL_FA_VARARGS = 0x08,
	// Internal: has clause-reference
	PL_FA_CREF    = 0x10,
	// Internal: ISO core predicate
	PL_FA_ISO     = 0x20,
	// Additional meta-argument spec
	PL_FA_META    = 0x40
}

// Not win32
PL_extension[] PL_extensions;

export void PL_register_extensions(const PL_extension*);
export void PL_register_extensions_in_module(const char* moduleName, const PL_extension*);
export int  PL_register_foreign(
	const char* name,
	int arity,
	pl_function_t func,
	int flags,
	...);

export int PL_register_foreign_in_module(
	const char* moduleName,
	const char* name,
	int arity,
	pl_function_t func,
	int flags,
	...);

export int PL_load_extensions(const PL_extension*);


	/+++++++++++++++++++++
	+      License       +
	++++++++++++++++++++++/

export void PL_license(const char* license, const char* moduleName);

	/++++++++++++++++++++
	+      Modules      +
	+++++++++++++++++++++/

export module_t PL_context();
export atom_t   PL_module_name(module_t);
export module_t PL_new_module(atom_t name);
export int      PL_strip_module(term_t input, module_t* m, term_t output);

	/++++++++++++++++++++++
	+      Constants      +
	+++++++++++++++++++++++/

export const(atom_t)* _PL_atoms();

	/++++++++++++++++++++++
	+      Call-back      +
	+++++++++++++++++++++++/

enum
{
	// Kernel only, = TRUE for backward compatibility
	PL_Q_DEBUG = 0x0001,
	// Normal usage
	PL_Q_NORMAL = 0x0002,
	// Use this one
	PL_Q_NODEBUG = 0x0004,
	// Handle exceptions in D
	PL_Q_CATCH_EXCEPTION = 0x0008,
	// Pass to parent environment
	PL_Q_PASS_EXCEPTION = 0x0010,
	// Support I_YIELD
	PL_Q_ALLOW_YIELD = 0x0020,
	// Return extended status
	PL_Q_EXT_STATUS = 0x0040,
	// Kernel only, the call was deterministic
	PL_Q_DETERMINISTIC = 0x0100,
}

/+ PL_Q_EXT_STATUS return codes +/
enum
{
	// Query raised an exception
	PL_S_EXCEPTION = -1,
	// Query failed
	PL_S_FALSE = 0,
	// Query succeeded with choicepoint
	PL_S_TRUE = 1,
	// Query succeeded without CP
	PL_S_LAST = 2
}

	/+ Foreign context frames +/
export fid_t PL_open_foreign_frame();
export void PL_rewind_foreign_frame(fid_t);
export void PL_close_foreign_frame(fid_t);
export void PL_discard_foreign_frame(fid_t);

	/+ Finding predicates +/
export predicate_t PL_pred(functor_t, module_t);
export predicate_t PL_predicate(const char* name, int arity, const char* moduleName);
export int         PL_predicate_info(predicate_t, 
	                                 atom_t* name,
	                                 size_t* arity,
	                                 module_t* moduleName
                   );

	/+ Call-back +/
export qid_t PL_open_query (module_t m, int flags, predicate_t pred, term_t t0);
export int   PL_next_solution(qid_t);
export int   PL_close_query(qid_t);
export int   PL_cut_query(qid_t);
export qid_t PL_current_query();

	/+ Simplified (but less flexible) call-back +/
export int PL_call(term_t, module_t);
export int PL_call_predicate(module_t, int p_debug, predicate_t, term_t t0);

	/+ Handling exceptions +/
export term_t PL_exception(qid_t qid);
export int    PL_raise_exception(term_t exception);
export int    PL_throw(term_t);
export void   PL_clear_exception();

	/+ Engine-based coroutining +/
export term_t PL_yielded(qid_t);

	/++++++++++++++++++++++++++++
	+      Term-references      +
	+++++++++++++++++++++++++++++/

	/+ Creating and destroying term-refs +/
export term_t PL_new_term_refs(int n);
export term_t PL_new_term_ref();
export term_t PL_copy_term_ref(term_t);
export void   PL_reset_term_refs(term_t);

	/+ Constants +/
export atom_t PL_new_atom(const char*);
export atom_t PL_new_atom_nchars(size_t len, const(char*));
export atom_t PL_new_atom_wchars(size_t len, const(pl_wchar_t*));
export atom_t PL_new_atom_mbchars(int rep, size_t len, const(char*));

export const(char*) PL_atom_chars(atom_t);
export const(char*) PL_atom_nchars(atom_t, size_t* len);
export const(wchar*) PL_atom_wchars(atom_t, size_t* len);

version(PL_Debug_AtomGC)
{
	export void PL_register_atom(atom_t);
	export void PL_unregister_atom(atom_t);
}

export functor_t PL_new_functor_sz(atom_t, size_t arity);
export functor_t PL_new_functor(atom_t, int arity);
export atom_t PL_functor_name(functor_t);
export int    PL_functor_arity(functor_t);
export size_t PL_functor_arity_sz(functor_t);


	/+ Get C-values from Prolog terms +/
export int PL_get_atom(term_t, atom_t*);
export int PL_get_bool(term_t, int*value);
export int PL_get_atom_chars(term_t, char**);

deprecated export int PL_get_string(term_t, char**, size_t* len);
alias PL_get_string_chars = PL_get_string;

export int PL_get_chars(term_t, char**, uint flags);
export int PL_get_list_chars(term_t, char**, uint flags);
export int PL_get_atom_nchars(term_t, size_t*, char**);
export int PL_get_list_nchars(term_t, size_t*, char**, uint flags);

export int PL_get_integer(term_t, int*);
export int PL_get_long(term_t, long*);
export int PL_get_intptr(term_t, intptr_t*);
export int PL_get_pointer(term_t, void**);
export int PL_get_float(term_t, double*);
export int PL_get_functor(term_t, functor_t*);

export int PL_get_name_arity_sz(term_t, atom_t*, size_t*);
export int PL_get_compound_name_arity_sz(term_t, atom_t*, size_t*);
export int PL_get_name_arity(term_t, atom_t*, int*);
export int PL_get_compound_name_arity(term_t, atom_t*, int*);

export int PL_get_module(term_t, module_t*);
export int PL_get_arg_sz(size_t index, term_t, term_t);
export int PL_get_arg (int index, term_t, term_t);
export int PL_get_list (term_t, term_t head, term_t tail);
export int PL_get_head (term_t, term_t head);
export int PL_get_tail (term_t, term_t tail);

export int PL_get_nil (term_t);
export int PL_get_term_value (term_t, term_value_t*);

export char* PL_quote(int chr, const char* data);

	/+ Verify types +/

export int PL_term_type(term_t t);
export int PL_is_variable(term_t t);
export int PL_is_ground(term_t t);
export int PL_is_atom(term_t t);
export int PL_is_integer(term_t t);
export int PL_is_string(term_t t);
export int PL_is_float(term_t t);
export int PL_is_rational(term_t t);
export int PL_is_compound(term_t t);
export int PL_is_callable(term_t t);
export int PL_is_functor(term_t t, functor_t f);
export int PL_is_list(term_t t);
export int PL_is_pair(term_t t);
export int PL_is_atomic(term_t t);
export int PL_is_number(term_t t);
export int PL_is_acyclic(term_t t);

	/+ Assign to term-references +/

export int PL_put_variable(term_t t);
export int PL_put_atom(term_t t, atom_t a);
export int PL_put_bool(term_t t, int val);
export int PL_put_atom_chars(term_t t, const char*chars);
export int PL_put_string_chars(term_t t, const char*chars);
export int PL_put_chars(term_t t,
                        int flags,
                        size_t len, 
                        const char*chars
                       );

export int PL_put_list_chars(term_t t, const char*chars);
export int PL_put_list_codes(term_t t, const char*chars);
export int PL_put_atom_nchars(term_t t, size_t l, const char*chars);
export int PL_put_string_nchars(term_t t, size_t len, const char*chars);
export int PL_put_list_nchars(term_t t, size_t l, const char*chars);
export int PL_put_list_ncodes(term_t t, size_t l, const char*chars);
export int PL_put_integer(term_t t, long i);
export int PL_put_pointer(term_t t, void*ptr);
export int PL_put_float(term_t t, double f);
export int PL_put_functor(term_t t, functor_t functor);
export int PL_put_list(term_t l);
export int PL_put_nil(term_t l);
export int PL_put_term(term_t t1, term_t t2);

	/+ Unify term-references +/

export int PL_unify(term_t t1, term_t t2);
export int PL_unify_atom(term_t t, atom_t a);
export int PL_unify_atom_chars(term_t t, const char*chars);
export int PL_unify_list_chars(term_t t, const char*chars);
export int PL_unify_list_codes(term_t t, const char*chars);
export int PL_unify_string_chars(term_t t, const char*chars);
export int PL_unify_atom_nchars(term_t t, size_t l, const char*s);
export int PL_unify_list_ncodes(term_t t, size_t l, const char*s);
export int PL_unify_list_nchars(term_t t, size_t l, const char*s);
export int PL_unify_string_nchars(term_t t,
                                  size_t len,
                                  const char*chars
                                 );
export int PL_unify_bool(term_t t, int n);
export int PL_unify_integer(term_t t, intptr_t n);
export int PL_unify_float(term_t t, double f);
export int PL_unify_pointer(term_t t, void*ptr);
export int PL_unify_functor(term_t t, functor_t f);
export int PL_unify_compound(term_t t, functor_t f);
export int PL_unify_list(term_t l, term_t h, term_t t);
export int PL_unify_nil(term_t l);
export int PL_unify_arg_sz(size_t index, term_t t, term_t a);
export int PL_unify_arg(int index, term_t t, term_t a);
export int PL_unify_term(term_t t, ...);
export int PL_unify_chars(term_t t, 
                          int flags,
                          size_t len, 
                          const char*s
                         );

	/++++++++++++++++++
	+      Lists      +
	+++++++++++++++++++/

export int PL_skip_list(term_t list, term_t tail, size_t* len);

	/++++++++++++++++++++++++++++++++++++
	+      Wide Character Versions      +
	+++++++++++++++++++++++++++++++++++++/


export int PL_unify_wchars(term_t,
                           int type,
                           size_t len,
                           const pl_wchar_t*
                          );
export int PL_unify_wchars_diff(term_t,
                                term_t tail,
                                int type,
                                size_t len,
                                const pl_wchar_t*
                               );
export int PL_get_wchars(term_t,
                         size_t*,
                         pl_wchar_t**,
                         uint flags
                        );
export size_t PL_utf8_strlen(const char*, size_t);


	/++++++++++++++++++++++++++
	+      Wide Integers      +
	+++++++++++++++++++++++++++/


export int PL_get_int64(term_t, int64_t*);
export int PL_unify_int64(term_t, int64_t);
export int PL_unify_uint64(term_t, uint64_t);
export int PL_put_int64(term_t, int64_t);

	/+++++++++++++++++++++++++++++++++
	+      Attributed Variables      +
	++++++++++++++++++++++++++++++++++/

export int PL_is_attvar(term_t);
export int PL_get_attr(term_t, term_t);

	/+++++++++++++++++++
	+      Errors      +
	++++++++++++++++++++/

export int PL_get_atom_ex(term_t, atom_t*);
export int PL_get_integer_ex(term_t, int*);
export int PL_get_long_ex(term_t, long*);
export int PL_get_int64_ex(term_t, int64_t*);
export int PL_get_intptr_ex(term_t, intptr_t*);
export int PL_get_size_ex(term_t, size_t*);
export int PL_get_bool_ex(term_t, int*);
export int PL_get_float_ex(term_t, double*);
export int PL_get_char_ex(term_t, int*p, int eof);
export int PL_unify_bool_ex(term_t, int);
export int PL_get_pointer_ex(term_t, void**);
export int PL_unify_list_ex(term_t, term_t head, term_t tail);
export int PL_unify_nil_ex(term_t);
export int PL_get_list_ex(term_t, term_t head, term_t tail);
export int PL_get_nil_ex(term_t);

export int PL_instantiation_error(term_t);
export int PL_uninstantiation_error(term_t);
export int PL_representation_error(const char*);
export int PL_type_error(const char*expected, term_t);
export int PL_domain_error(const char*expected, term_t);
export int PL_existence_error(const char*type, term_t);
export int PL_permission_error(const char*operation,
                               const char*type,
                               term_t
                              );
export int PL_resource_error(const char*);

version(PL_SIO_Magic)
	export int PL_syntax_error(const char*msg, IOSTREAM*inStream);
else
	export int PL_syntax_error(const char*msg, void*inStream);

	/++++++++++++++++++
	+      Blobs      +
	+++++++++++++++++++/

// Magic to validate a blob-type
enum PL_BLOB_MAGIC_B = 0x75293a00;
// Current blob version
enum PL_BLOB_VERSION = 1;
enum PL_BLOB_MAGIC = PL_BLOB_MAGIC_B|PL_BLOB_VERSION;

enum : uintptr_t
{
	// Contents are unique
	PL_BLOB_UNIQUE = 0x01,
	// Contains text
	PL_BLOB_TEXT   = 0x02,
	// Do not copy the data
	PL_BLOB_NOCOPY = 0x04,
	// Wide character string
	PL_BLOB_WCHAR  = 0x08
}

struct PL_blob_t
{
	// PL_BLOB_MAGIC
	uintptr_t magic;
	// PL_BLOB_*
	uintptr_t flags;
	// Name of the type
	char* name;

	int function(atom_t) release;
	int function(atom_t, atom_t) compare;

	version(PL_SIO_Magic)
		int function(IOSTREAM*, atom_t, int flags) write;
	else
		int function(void* atom_t, int flags) write;

	void function(atom_t) acquire;

	version(PL_SIO_Magic)
	{
		int function(atom_t, IOSTREAM*) save;
		atom_t function(IOSTREAM*) load;
	}
	else
	{
		int function(atom_t, void*) save;
		atom_t function(void*) load;
	}
	// Required 0-padding
	size_t padding;
	// For future extension
	void*[9] reserved;
	// Already registered?
	int registered;
	// Rank for ordering atoms
	int rank;
	// Next in registered type-chain
	PL_blob_t* next;
	// Name as an atom
	atom_t atom_name;
}

export int PL_is_blob(term_t t, PL_blob_t**type);
export int PL_unify_blob(term_t t,
                         void*blob,
                         size_t len,
                         PL_blob_t*type
                        );
export int PL_put_blob(term_t t, 
                       void*blob,
                       size_t len,
                       PL_blob_t*type
                      );
export int PL_get_blob(term_t t,
                       void**blob,
                       size_t*len,
                       PL_blob_t**type
                      );

export void* PL_blob_data(atom_t a,
                          size_t*len,
                          PL_blob_t**
                         );

export void PL_register_blob_type(PL_blob_t*type);
export PL_blob_t* PL_find_blob_type(const char* name);
export int PL_unregister_blob_type(PL_blob_t*type);


version(PL_Use_GNU_MP)
{
	export int PL_get_mpz(term_t t, mpz_t mpz);
	export int PL_get_mpq(term_t t,  mpq_t mpq);
	export int PL_unify_mpz(term_t t, mpz_t mpz);
	export int PL_unify_mpq(term_t t, mpq_t mpq);
}

	/+++++++++++++++++++++++++++++
	+      Filename support      +
	++++++++++++++++++++++++++++++/

enum : int
{
	// Return absolute path
	PL_FILE_ABSOLUTE = 0x01,
	// Return path in OS notation
	PL_FILE_OSPATH   = 0x02,
	// Use file_search_path
	PL_FILE_SEARCH   = 0x04,
	// Demand file to exist
	PL_FILE_EXIST    = 0x08,
	// Demand read-access
	PL_FILE_READ     = 0x10,
	// Demand write-access
	PL_FILE_WRITE    = 0x20,
	// Demand execute-access
	PL_FILE_EXECUTE  = 0x40,
	// Do not raise exceptions
	PL_FILE_NOERRORS = 0x80
}

export int PL_get_file_name(term_t, char**, int flags);
export int PL_get_file_nameW(term_t, wchar**, int flags);
/// Foreign code changed CWD
export void PL_changed_cwd();
export char* PL_cwd(char*buf, size_t buflen);

	/+++++++++++++++++++++++++++++++++
	+     Quintus/Sictus Wrapper     +
	++++++++++++++++++++++++++++++++++/

export int PL_cvt_i_char(term_t, char*);
export int PL_cvt_i_uchar(term_t, ubyte*);
export int PL_cvt_i_short(term_t, ushort*);
export int PL_cvt_i_ushort(term_t, ushort*);
export int PL_cvt_i_int(term_t, int*);
export int PL_cvt_i_uint(term_t, uint*);
export int PL_cvt_i_long(term_t, long*);
export int PL_cvt_i_ulong(term_t, ulong*);
export int PL_cvt_i_int64(term_t, int64_t*);
export int PL_cvt_i_uint64(term_t, uint64_t*);
export int PL_cvt_i_size_t(term_t, size_t*);
export int PL_cvt_i_float(term_t, double*);
export int PL_cvt_i_single(term_t, float*);
export int PL_cvt_i_string(term_t, char*);
export int PL_cvt_i_codes(term_t, char*);
export int PL_cvt_i_atom(term_t, atom_t*);
export int PL_cvt_i_address(term_t, void*);
export int PL_cvt_o_int64(int64_t c, term_t);
export int PL_cvt_o_float(double c, term_t);
export int PL_cvt_o_single(float c, term_t);
export int PL_cvt_o_string(const char*, term_t);
export int PL_cvt_o_codes(const char*, term_t);
export int PL_cvt_o_atom(atom_t c, term_t);
export int PL_cvt_o_address(void*, term_t);
export term_t PL_new_nil_ref();

/* set/get encoding for PL_cvt_*_string() functions.  The default
   is UTF-8 (REP_UTF8)
*/
export int PL_cvt_encoding();
export int PL_cvt_set_encoding(int);
export void SP_set_state(int);
export int SP_get_state();

	/++++++++++++++++++++
	+      Compare      +
	+++++++++++++++++++++/

export int PL_compare(term_t t1, term_t t2);
export int PL_same_compound(term_t t1, term_t t2);

		 /*******************************
		*	     MESSAGES		*
		*******************************/

export int PL_warning(const char*fmt, ...);
export void PL_fatal_error(const char*fmt, ...);

		 /*******************************
		*      RECORDED DATABASE	*
		*******************************/

export record_t PL_record(term_t term);
export int PL_recorded(record_t record, term_t term);
export void PL_erase(record_t record);
export record_t PL_duplicate_record(record_t r);

export char* PL_record_external(term_t t, size_t*size);
export int PL_recorded_external(const char*rec, term_t term);
export int PL_erase_external(char*rec);

	/+++++++++++++++++++++++++
	+      Prolog Flags      +
	++++++++++++++++++++++++++/

// Compatibility
alias PL_set_feature = PL_set_prolog_flag;
export int PL_set_prolog_flag(const char*name, int type, ...);

	/+++++++++++++++++++++++++++++
	+     Internal Functions     +
	++++++++++++++++++++++++++++++/

export PL_atomic_t _PL_get_atomic(term_t);
export void _PL_put_atomic(term_t, PL_atomic_t a);
export int _PL_unify_atomic(term_t, PL_atomic_t a);
export void _PL_get_arg_sz(size_t index, term_t t, term_t a);
export void _PL_get_arg(int index, term_t t, term_t a);


	/+++++++++++++++++++++++
	+     Char Buffers     +
	++++++++++++++++++++++++/

enum
{
	CVT_ATOM     = 0x0001,
	CVT_STRING   = 0x0002,
	CVT_LIST     = 0x0004,
	CVT_INTEGER  = 0x0008,
	CVT_FLOAT    = 0x0010,
	CVT_VARIABLE = 0x0020,
	CVT_NUMBER   = (CVT_INTEGER|CVT_FLOAT),
	CVT_ATOMIC   = (CVT_NUMBER|CVT_ATOM|CVT_STRING),
	CVT_WRITE    = 0x0040,
	CVT_WRITE_CANONICAL = 0x0080,
	CVT_WRITEQ   = 0x00C0,
	CVT_ALL      = (CVT_ATOMIC|CVT_LIST),
	CVT_MASK     = 0x00ff,
}

enum 
{
	BUF_DISCARDABLE = 0x0000,
	BUF_RING = 0x0100,
	BUF_MALLOC = 0x0200,
	// Allow pointer into (global) stack
	BUF_ALLOW_STACK = 0x0400,
}

enum
{
	// Throw an exception on error
	CVT_EXCEPTION = 0x10000,
	// Return 2 if argument is unbound
	CVT_VARNOFAIL = 0x20000	
}


/+ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Output   representation   for   PL_get_chars()     and    friends.   The
prepresentation type REP_FN is for   PL_get_file_name()  and friends. On
Windows we use UTF-8 which is translated   by the `XOS' layer to Windows
UNICODE file functions.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +/

version(Windows)
	private enum rep_fn_value = 0x1000; //REP_UTF8
else
	private enum rep_fn_value = 0x2000; // REP_MB

enum
{
	REP_ISO_LATIN_1 = 0x0000,
	REP_UTF8 = 0x1000,
	REP_MB   = 0x2000,
	REP_FN   = rep_fn_value,
}

// PL_unify_chars()
enum PL_DIFF_LIST = 0x20000;


version(PL_SIO_Magic)
{
	/+++++++++++++++++++++++++++
	+      Stream Support      +
	++++++++++++++++++++++++++++/

	/+ Make IOSTREAM known to Prolog +/
	// Compatibility
	alias PL_open_stream = PL_unify_stream;
	export int PL_unify_stream(term_t t, IOSTREAM*);
	export int PL_get_stream_handle(term_t t, IOSTREAM**s);
	export int PL_get_stream(term_t t, IOSTREAM**s, int flags);
	export IOSTREAM* PL_acquire_stream(IOSTREAM*s);
	export int PL_release_stream(IOSTREAM*s);
	export int PL_release_stream_noerror(IOSTREAM*s);
	export IOSTREAM* PL_open_resource(module_t m,
						 const char*name,
						 const char*rc_class,
						 const char*mode);

	// Base of streams
	export IOSTREAM** _PL_streams();

	enum : int
	{
		// Quote atoms
		PL_WRT_QUOTED     = 0x01,
		// Ignore list/operators
		PL_WRT_IGNOREOPS  = 0x02,
		// Print $VAR(N) as a variable
		PL_WRT_NUMBERVARS = 0x04,
		// Call portray
		PL_WRT_PORTRAY     = 0x08,
		// Output ISO escape sequences
		PL_WRT_CHARESCAPES = 0x10,
		// Write strings as `...`
		PL_WRT_BACKQUOTED_STRING = 0x20,
		// Write attributed variables
		// Default: just write the var
		PL_WRT_ATTVAR_IGNORE     = 0x040,
		// Write as Var{...}
		PL_WRT_ATTVAR_DOTS    = 0x080,
		// Write as Var{Attributes}
		PL_WRT_ATTVAR_WRITE   = 0x100,
		// Use Module:portray_attrs/2
		PL_WRT_ATTVAR_PORTRAY = 0x200,
		PL_WRT_ATTVAR_MASK    =
			(PL_WRT_ATTVAR_IGNORE | 
			 PL_WRT_ATTVAR_DOTS | 
			 PL_WRT_ATTVAR_WRITE | 
			 PL_WRT_ATTVAR_PORTRAY),
		// Use portray to emit non-text blobs
		PL_WRT_BLOB_PORTRAY = 0x400,
		// Never emit @(Template,Subst)
		PL_WRT_NO_CYCLES    = 0x800,
		// Add a newline
		PL_WRT_NEWLINE      = 0x2000,
		// Internal: variable_names(List)
		PL_WRT_VARNAMES     = 0x4000,
		// ` is a symbol char
		PL_WRT_BACKQUOTE_IS_SYMBOL = 0x8000,
		// Write lists as .(A,B)
		PL_WRT_DOTLISTS    = 0x10000,
		// Write {A} as {}(A)
		PL_WRT_BRACETERMS  = 0x20000,
		// Do not write dicts in pretty syntax
		PL_WRT_NODICT      = 0x40000,
		// Never write a.b unquoted
		PL_WRT_NODOTINATOM = 0x80000
	}

	export int PL_write_term(IOSTREAM*,
	                         term_t term,
	                         int precedence,
	                         int flags
	                        );

	/// PL_ttymode() results
	enum : int
	{
		// -tty in effect
		PL_NOTTY = 	0,
		// get_single_char/1
		PL_RAWTTY = 	1,
		// Normal input
		PL_COOKEDTTY = 	2
	}

	export int PL_ttymode(IOSTREAM*);
}

export int PL_put_term_from_chars(term_t, 
                                  int flags,
                                  size_t len,
                                  const char*
                                 );
export int PL_chars_to_term(const char*, term_t);
export int PL_wchars_to_term(const pl_wchar_t*, term_t);

	/++++++++++++++++++++++
	+      Embedding      +
	+++++++++++++++++++++++/

export int PL_initialise(int argc, char**argv);
export int PL_is_initialised(int*argc, char***argv);
export int PL_set_resource_db_mem(const ubyte*data, size_t size);
export int PL_toplevel();
export int PL_cleanup(int status);
export void PL_cleanup_fork();
export int PL_halt(int status);

	/++++++++++++++++++++++++++++
	+      Dynamic linking      +
	+++++++++++++++++++++++++++++/

export void* PL_dlopen(const char*file, int flags);
export const(char*) PL_dlerror();
export void* PL_dlsym(void*handle, char*symbol);
export int PL_dlclose(void*handle);


	/++++++++++++++++++++++++++++
	+     Input/Prompt/Etc.     +
	+++++++++++++++++++++++++++++/

/+ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
NOTE: the functions in this section are   not  documented, as as yet not
adviced for public usage.  They  are   intended  to  provide an abstract
interface for the GNU readline  interface   as  defined  in the readline
package.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -+/

/// PL_dispatch() modes
enum : int
{
	// Dispatch only once
	PL_DISPATCH_NOWAIT    = 0,
	// Dispatch until input available
	PL_DISPATCH_WAIT      = 1,
	// Dispatch function installed ?
	PL_DISPATCH_INSTALLED = 2
}

export int PL_dispatch(int fd, int wait);
export void PL_add_to_protocol(const char*buf, size_t count);
export char* PL_prompt_string(int fd);
export void PL_write_prompt(int dowrite);
export void PL_prompt_next(int fd);
export char* PL_atom_generator(const char*prefix, int state);

export pl_wchar_t* PL_atom_generator_w(const pl_wchar_t*pref,
                                       pl_wchar_t*buffer,
                                       size_t buflen,
                                       int state
                                      );


	/++++++++++++++++++++++++++++
	+     Memory allocation     +
	+++++++++++++++++++++++++++++/

export void* PL_malloc(size_t);
export void* PL_malloc_atomic(size_t);
export void* PL_malloc_uncollectable(size_t);
export void* PL_malloc_atomic_uncollectable(size_t);
export void* PL_realloc(void*, size_t);
export void* PL_malloc_unmanaged(size_t);
export void* PL_malloc_atomic_unmanaged(size_t);
export void  PL_free(void*);
export int   PL_linger(void*);


	/++++++++++++++++++
	+      Hooks      +
	+++++++++++++++++++/

enum : int
{
	// There is input available
	PL_DISPATCH_INPUT   = 0,
	// Dispatch timeout
	PL_DISPATCH_TIMEOUT = 1
}

alias PL_dispatch_hook_t = int function(int fd);
alias PL_abort_hook_t = void function();
alias PL_initialise_hook_t = void function(int argc, char** argv);
alias PL_agc_hook_t = int function(atom_t);

export PL_dispatch_hook_t PL_dispatch_hook(PL_dispatch_hook_t);
export PL_agc_hook_t PL_agc_hook(PL_agc_hook_t);
export void PL_initialise_hook(PL_initialise_hook_t);
export void PL_abort_hook(PL_abort_hook_t);
export int  PL_abort_unhook(PL_abort_hook_t);

	/++++++++++++++++++++
	+      Signals      +
	+++++++++++++++++++++/		

/// PL_signal() masks
deprecated enum : int
{
	// Call handler synchronously
	PL_SIGSYNC = 0x00010000,
	// Do not create Prolog frame
	PL_SIGNOFRAME = 0x00020000
}

enum  : int
{
	// Throw signal(num, name)
	PLSIG_THROW   = 0x0002,
	// Call sychronously
	PLSIG_SYNC    = 0x0004,
	// Do not create a Prolog frame
	PLSIG_NOFRAME = 0x0008
}

struct pl_sigaction_t
{
	//Traditional C function
	void function(int) sa_cfunction;
	// Call a predicate
	predicate_t sa_predicate;
	// Additional flags
	int         sa_flags;
	// Future extensions
	void*[2] reserved;
}

export void function(int) 
	PL_signal( int sig, void function(int) );

export int  PL_sigaction(int sig, pl_sigaction_t*act, pl_sigaction_t*old);
export void PL_interrupt(int sig);
export int  PL_raise(int sig);
export int  PL_handle_signals();
export int  PL_get_signum_ex(term_t sig, int*n);

	/++++++++++++++++++++++++++++++
	+     Prolog Action/Query     +
	+++++++++++++++++++++++++++++++/

enum : int
{
	// Switch to trace mode
	PL_ACTION_TRACE = 1,
	// Switch to debug mode
	PL_ACTION_DEBUG = 2,
	// Show a backtrace (stack dump)
	PL_ACTION_BACKTRACE = 3,
	// Creat a break environment
	PL_ACTION_BREAK = 4,
	// Halt Prolog execution
	PL_ACTION_HALT = 5,
	// Generate a Prolog abort
	PL_ACTION_ABORT = 6,
	// 7: Obsolete PL_ACTION_SYMBOLFILE
	// Write via Prolog IO buffer
	PL_ACTION_WRITE = 8,
	// Flish Prolog IO buffer
	PL_ACTION_FLUSH = 9,
	// Win32: set when this is a GUI
	PL_ACTION_GUIAPP = 10,
	// MT: Attach a console
	PL_ACTION_ATTACH_CONSOLE = 11,
	// GMP: do not change allocation functions
	PL_GMP_SET_ALLOC_FUNCTIONS = 12,
	// Set --traditional
	PL_ACTION_TRADITIONAL = 13
}

enum : int
{
	// Do not try to print goals
	PL_BT_SAFE = 0x1,
	// Only show user-goals
	PL_BT_USER = 0x2,
}

// Perform some action
export int PL_action(int, ...);
export void PL_on_halt(int function(int, void*), void*);
export void PL_exit_hook(int function(int, void*), void*);
export void PL_backtrace(int depth, int flags);
export char* PL_backtrace_string(int depth, int flags);
export int PL_check_data(term_t data);
export int PL_check_stacks();
export int PL_current_prolog_flag(atom_t name, int type, void*ptr);

	/+++++++++++++++++++++++++
	+      Query Prolog      +
	++++++++++++++++++++++++++/

enum : int
{
	PL_QUERY_ARGC = 1,
	PL_QUERY_ARGV = 2,
		// 3: Obselete PL_QUERY_SYMBOLFILE
		// 4: PL_QUERY_ORGSYMBOLFILE
	// Read character from terminal
	PL_QUERY_GETC = 5,
	// Largest integer
	PL_QUERY_MAX_INTEGER = 6,
	// Smallest integer
	PL_QUERY_MIN_INTEGER = 7,
	// Larges tagged integer
	PL_QUERY_MAX_TAGGED_INT = 8,
	// Smallest tagged integer
	PL_QUERY_MIN_TAGGED_INT = 9,
	// 207006 = 2.7.6
	PL_QUERY_VERSION = 10,
	// Maximum thread count
	PL_QUERY_MAX_THREADS = 11,
	// IO encoding
	PL_QUERY_ENCODING = 12,
	/// User CPU in milliseconds
	PL_QUERY_USER_CPU = 13,
	// If TRUE, we are in PL_cleanup()
	PL_QUERY_HALTING = 14,
}

// Get information from Prolog
export intptr_t PL_query(int);

	/+++++++++++++++++++++++++++
	+      Prolog Threads      +
	++++++++++++++++++++++++++++/

enum
{
	// Start thread in nodebug mode
	PL_THREAD_NO_DEBUG = 0x01,
	// Allow Prolog to join
	PL_THREAD_NOT_DETACHED = 0x02,
}

alias rc_cancel = intptr_t;
enum : rc_cancel
{
	// Failed to cancel, try abort
	PL_THREAD_CANCEL_FAILED = FALSE,
	// Cancelled and joined
	PL_THREAD_CANCEL_JOINED = TRUE,
	// Cancelled, must join
	PL_THREAD_CANCEL_MUST_JOIN
}

struct PL_thread_attr_t
{
	// Total stack limit, in bytes
	size_t    stack_limit;
	// Total tabling space limit, in bytes
	size_t    table_space;
	// Alias name
	// Note: originally `alias`, but that's reserved in D
	char*     alias_;
	// Cancel function
	rc_cancel function(int id) cancel;
	// PL_THREAD_* flags
	intptr_t  flags;
	// Max_queue_size
	size_t    max_queue_size;
	// Reserved for extensions
	void*[3]  reserved;
}

/// Prolog thread ID (-1 if none)
export int PL_thread_self();
export int PL_unify_thread_id(term_t t, int i);
export int PL_get_thread_id_ex(term_t t, int*idp);
/// Locks alias
export int PL_get_thread_alias(int tid, atom_t* p_alias);
export int PL_thread_attach_engine(PL_thread_attr_t*attr);
export int PL_thread_destroy_engine();

export int PL_thread_at_exit(void function(void*),
                             void*closure,
                             int global
                            );
export int PL_thread_raise(int tid, int sig);
version(Windows)
{
	export int PL_w32thread_raise(DWORD dwTid, int sig);
	export int PL_wait_for_console_input(void*handle);
	export int PL_w32_wrap_ansi_console();
	export const(char*) PL_w32_running_under_wine();
}

	/++++++++++++++++++++++++++++
	+     Engines (MT only)     +
	+++++++++++++++++++++++++++++/

enum : PL_engine_t
{
	PL_ENGINE_MAIN = cast(PL_engine_t)0x1,
	PL_ENGINE_CURRENT = cast(PL_engine_t)0x2,
}

enum 
{
	// Engine set successfully
	PL_ENGINE_SET = 0,
	// Engine doesn't exist
	PL_ENGINE_INVAL = 2,
	// Engine is in use
	PL_ENGINE_INUSE = 3,
}

export PL_engine_t PL_create_engine(PL_thread_attr_t* attributes);
export int PL_set_engine(PL_engine_t engine, PL_engine_t* old);
export int PL_destroy_engine(PL_engine_t engine);

	/+++++++++++++++++++++
	+      Profiler      +
	++++++++++++++++++++++/

struct PL_prof_type_t
{
	// Implementation --> Prolog
	int function(term_t, void*) unify;
	// Prolog --> implementation
	int function(term_t, void**) get;
	// (De)activate
	void function(int active) activate;
	// PROFTYPE_MAGIC
	intptr_t magic;
}

export int PL_register_profile_type(PL_prof_type_t*);
export void* PL_prof_call(void*, PL_prof_type_t*);
export void PL_prof_exit(void*);

	/+++++++++++++++++++++++++++
	+     Windows Messages     +
	++++++++++++++++++++++++++++/

version(Windows)
{
	enum
	{
		PL_MSG_EXCEPTION_RAISED = -1,
		PL_MSG_IGNORED = 0,
		PL_MSG_HANDLED = 1,
	}

	export LRESULT PL_win_message_proc(HWND hwnd,
	                                   UINT message,
	                                   WPARAM wParam,
	                                   LPARAM lParam
	                                  );
}

	/+++++++++++++++++++++++++++
	+     Fast XPCE Supprt     +
	++++++++++++++++++++++++++++/

struct xpceref_t
{
	// PL_INTEGER or PL_ATOM
	int type;
	union value_t
	{
		// Integer reference value
		uintptr_t i;
		// Atom Reference value
		atom_t	  a;
	}
	value_t value;
}

export int _PL_get_xpce_reference(term_t t, xpceref_t*);
export int _PL_unify_xpce_reference(term_t t, xpceref_t*);
export int _PL_put_xpce_reference_i(term_t t, uintptr_t r);
export int _PL_put_xpce_reference_a(term_t t, atom_t name);

	/++++++++++++++++++++++++++
	+      Trace Support      +
	+++++++++++++++++++++++++++/

alias QueryFrame = void*;
alias LocalFrame = void*;
alias Code = void*;

struct pl_context_t
{
	// Engine
	PL_engine_t ld;
	// Current Query
	QueryFrame  qf;
	// Current local frame
	LocalFrame  fr;
	// Code Pointer
	Code        pc;
	// Reserved for extensions
	void*[10]   reserved;
}

export int PL_get_context(pl_context_t*c, int thead_id);
export int PL_step_context(pl_context_t*c);
export int PL_describe_context(pl_context_t*c,
                               char*buf,
                               size_t len
                              );

version(PL_ArityAsSize)
{
	alias PL_new_functor = PL_new_functor_sz;
	alias PL_functor_arity = PL_functor_arity_sz;
	alias PL_get_name_arity = PL_get_name_arity_sz;
	alias PL_get_compound_name_arity = PL_get_compound_name_arity_sz;
	alias PL_get_arg = PL_get_arg_sz;
	alias PL_unify_arg = PL_unify_arg_sz;
	alias _PL_get_arg = _PL_get_arg_sz;
}