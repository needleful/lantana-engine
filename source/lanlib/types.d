// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.types;

/**
 A strict alias for a given type.
 To use, initialize a struct like this:

 struct MyAlias
 {
	mixin StrictAlias!Type;
 }
 */
mixin template StrictAlias(T)
{
	private T _handle;

	@disable this(U)(U u);

	this(U : U)(U data) @nogc @safe nothrow 
		if( is(U == T) )
	{
		_handle = data;
	}

	T handle() const nothrow @nogc @safe pure
	{
		return _handle;
	}

	T* ptr() nothrow @nogc pure
	{
		return &_handle;
	}

	alias handle this;
}

/// Check if Type is an instantiation of the Template
enum isTemplateType(alias Template, Type) = __traits(
	compiles,
	{
		void f(Specs...)(Template!Specs value){}
		f(Type.init);
	}
);

/// Create a bitfield from an enum
struct Bitfield(Enum)
	if(is(Enum == enum))
{
	static if(Enum.max < 8)
	{
		alias dt = ubyte;
	}
	else static if(Enum.max < 16)
	{
		alias dt = ushort;
	}
	else static if(Enum.max < 32)
	{
		alias dt = uint;
	}
	else static if(Enum.max < 64)
	{
		alias dt = ulong;
	}
	else
	{
		static assert(false, "currently no support for enums with values larger than 64");
	}

	private dt data;

	public bool opIndex(Enum p_index)
	{
		dt mask = cast(dt)(1 << p_index);
		return (data & mask) != 0;
	}

	public void opIndexAssign(bool p_value, Enum p_index)
	{
		// set the flag to zero
		dt inverseMask = ~(cast(dt)(1 << p_index));
		data &= inverseMask;

		// set the bit to 0 or 1
		// bools are 1-bit ints, so this is either 0 or 1<<p_index
		dt mask = cast(dt)(p_value << p_index);
		data |= mask;
	}
}