// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.math.vectors;

import std.math;
import lantana.math.matrix;


alias Vec2 = Vector!(float, 2);
alias Vec3 = Vector!(float, 3);
alias Vec4 = Vector!(float, 4);

alias iVec2 = Vector!(int, 2);
alias iVec3 = Vector!(int, 3);
alias iVec4 = Vector!(int, 4);

alias uVec2 = Vector!(uint, 2);
alias uVec3 = Vector!(uint, 3);
alias uVec4 = Vector!(uint, 4);

struct Vector(T, uint Size)
{
	static enum size = Size;
	alias dataType = T;
	alias Self = Vector!(T, Size);
	static assert(Size > 0);

	T[Size] data;

	this(const T[Size] d) @nogc @safe nothrow
	{
		data = d;
	}

	this(Self rhs) @nogc @safe nothrow {
		data = rhs.data;
	}

	this(A...)(A args)
		if(args.length == Size)
	{
		static foreach(uint i; 0..Size) {
			data[i] = cast(T)args[i];
		}
	}

	this(const T val) @nogc @safe nothrow
	{
		static foreach(uint i; 0..Size)
		{
			data[i] = val;
		}
	}

	const Self opUnary(string op)() @nogc @safe nothrow
	{
		Self result;
		static if(op == "-")
		{
			static foreach(uint i; 0..Size)
			{
				result.data[i] = -data[i];
			}
		}
		else
		{
			static assert(false, "Unknown unary vector operator: "~op);
		}
		return result;
	}

	@property const double length_squared() @nogc @safe
	{
		return dot(this);
	}

	@property const double length() @nogc @safe nothrow
	{
		return sqrt(length_squared());
	}

	void normalize() @nogc @safe nothrow
	{
		this /= length();
	}

	@property const Self normalized() {
		return this/length();
	}

	@property T *ptr() @nogc @safe nothrow
	{
		return &data[0];
	}

	@property const uint bytesize() @nogc @safe nothrow
	{
		return Size*T.sizeof;
	}

	@property ref T x() @nogc @safe nothrow
	{
		return data[0];
	}

	@property const T x() @nogc @safe nothrow
	{
		return data[0];
	}

	alias x r;

	static if (Size >= 2)
	{
		@property ref T y() @nogc @safe nothrow
		{
			return data[1];
		}

		@property const T y() @nogc @safe nothrow
		{
			return data[1];
		}

		alias y g;
	}
	static if (Size >= 3)
	{
		@property ref T z() @nogc @safe nothrow
		{
			return data[2];
		}

		@property const T z() @nogc @safe nothrow
		{
			return data[2];
		}

		alias z b;
	}
	static if (Size >= 4)
	{
		@property ref T w() @nogc @safe nothrow
		{
			return data[3];
		}

		@property const T w() @nogc @safe nothrow
		{
			return data[3];
		}

		alias w a;
	}

	auto swizzle(string properties)() @nogc @safe const {
		Vector!(T, properties.length) val;
		static foreach (int i, char c; properties) {
			mixin("val.data[i] = this."~c~";");
		}
		return val;
	}

	Self opBinary(string op, U)(const U val) @nogc @safe const
	{
		auto v = Self();
		static foreach(uint i; 0..Size)
		{
			mixin("v.data[i] = data[i]"~op~"val;");
		}
		return v;
	}

	const Self opBinary(string op)(const Self rhs) @nogc @safe nothrow
	{
		auto v = Self();
		static foreach(uint i; 0..Size)
		{
			mixin("v.data[i] = data[i] "~op~"rhs.data[i];");
		}
		return v;
	}

	void opOpAssign(string op)(const Self rhs) @nogc @safe nothrow
	{
		static foreach(uint i; 0..Size)
		{
			mixin("data[i] "~op~"= rhs.data[i];");
		}
	}

	void opOpAssign(string op, U)(const U val) @nogc @safe nothrow
	{
		static foreach(uint i; 0..Size)
		{
			mixin("data[i] "~op~"= val;");
		}
	}

	static if(!is(T == double)) {
		const Self opBinary(string op)(const double val) @nogc @safe nothrow {
			return opBinary!op(cast(T) val);
		}

		void opOpAssign(string op)(const double val) @nogc @safe nothrow {
			opOpAssign!op(cast(T) val);
		}
	}

	const Vector!(T, Column) mult(uint Column)(Matrix!(T, Size, Column) mat) @nogc @safe nothrow
	{
		Vector!(T, Column) temp;
		static foreach(uint i; 0..Column)
		{
			static foreach(uint j; 0..Size)
			{
				temp[i] += data[j]*mat[i, j];
			}
		}
		return temp;
	}

	const T dot(Self rhs) @nogc @safe nothrow
	{
		T res = 0;
		static foreach(uint i; 0..Size)
		{
			res += data[i] * rhs.data[i];
		}
		return res;
	}

	static if(Size == 3)
	{
		Self cross(Self rhs) @nogc @safe nothrow
		{
			return(Self(
				y*rhs.z - z*rhs.y,
				-(x*rhs.z - z*rhs.x),
				x*rhs.y - y*rhs.x)
			);
		}
	}

	ref T opIndex(uint ind) @nogc @safe nothrow
	{
		return data[ind];
	}

	const T opIndex(uint ind) @nogc @safe nothrow
	{
		return data[ind];
	}

	const bool opEquals()(auto ref const Self rhs) @nogc @safe nothrow
	{
		bool result = true;
		static foreach(uint i; 0..Size)
		{
			result = result && (data[i] == rhs.data[i]);
		}
		return result;
	}
}