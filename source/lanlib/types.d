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

	@property T handle() const nothrow @nogc @safe pure
	{
		return _handle;
	}

	@property T* ptr() nothrow @nogc pure
	{
		return &_handle;
	}

	alias handle this;
}