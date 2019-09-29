// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.math.vector;

import std.math;

import lanlib.math.matrix;

alias Vec2 = Vector!(float, 2);
alias Vec3 = Vector!(float, 3);
alias Vec4 = Vector!(float, 4);

alias iVec2 = Vector!(int, 2);
alias iVec3 = Vector!(int, 3);

struct Vector(T, uint Size)
{
	static assert(Size > 0, "Attempted Vector instantiated with Size <= 0");
	T[Size] data;

	this(const T[Size] d) @nogc @safe nothrow
	{
		data = d;
	}

	this(const T val) @nogc @safe nothrow
	{
		static foreach(uint i; 0..Size)
		{
			data[i] = val;
		}
	}

	const Vector!(T, Size) opUnary(string op)() @nogc @safe nothrow
	{
		Vector!(T, Size) result;
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
		double l_sq = 0;
		static foreach(uint i; 0..Size)
		{
			l_sq += data[i]*data[i];
		}
		return l_sq;
	}

	@property const double length() @nogc @safe nothrow
	{
		return sqrt(length_squared);
	}

	void normalize() @nogc @safe nothrow
	{
		T len = cast(T)length;
		static foreach(uint i; 0..Size)
		{
			data[i] /= len;
		}
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

		static if (Size == 2)
		{
			@nogc this(T x, T y)
			{
				data[0] = x;
				data[1] = y;
			}
		}
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

		static if(Size == 3)
		{
			@nogc @safe this(T x, T y, T z)
			{
				data[0] = x;
				data[1] = y;
				data[2] = z;
			}
		}
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

		static if(Size == 3)
		{
			@nogc @safe this(T x, T y, T z, T w)
			{
				data[0] = x;
				data[1] = y;
				data[2] = z;
				data[3] = w;
			}
		}
	}

	Vector!(T, Size) opBinary(string op)(const double val) @nogc @safe const
	{
		auto v = Vector!(T, Size)();
		static foreach(uint i; 0..Size)
		{
			static if(op == "*")
			{
				v.data[i] = cast(T)(data[i]*val);
			}
			else static if(op == "/")
			{
				v.data[i] = cast(T)(data[i]/val);
			}
			else static assert(false, "Operator not supported for vectors and scalars: "~op);
		}
		return v;
	}

	const Vector!(T, Size) opBinary(string op)(const Vector!(T, Size) rhs) @nogc @safe nothrow
	{
		auto v = Vector!(T, Size)();
		static foreach(uint i; 0..Size)
		{
			static if(op == "+")
			{
				v.data[i] = cast(T)(data[i] + rhs.data[i]);
			}
			else static if(op == "-")
			{
				v.data[i] = cast(T)(data[i] - rhs.data[i]);
			}
			else
			{
				static assert(false, "Operator not supported between vectors: "~op);
			}
		}
		return v;
	}

	void opOpAssign(string op)(const Vector!(T, Size) rhs) @nogc @safe nothrow
	{
		static foreach(uint i; 0..Size)
		{
			static if(op == "+")
			{
				data[i] += rhs.data[i];
			}
			else static if(op == "-")
			{
				data[i] -= rhs.data[i];
			}
			else
			{
				static assert(false, "Operator not supported between vectors: "~op);
			}
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

	const Vector!(T, Size) lerp(Vector!(T, Size) rhs, float factor)
	{
		return this + ((rhs-this)*factor);
	}

	const T dot(Vector!(T, Size) rhs) @nogc @safe nothrow
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
		Vector!(T, Size) cross(Vector!(T, Size) rhs) @nogc @safe nothrow
		{
			return(Vector!(T, Size)(
				cast(T) (y*rhs.z - z*rhs.y),
				cast(T) (-(x*rhs.z - z*rhs.x)),
				cast(T) (x*rhs.y - y*rhs.x))
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

	const bool opEquals()(auto ref const Vector!(T, Size) rhs) @nogc @safe nothrow
	{
		bool result = true;
		static foreach(uint i; 0..Size)
		{
			result = result && (data[i] == rhs.data[i]);
		}
		return result;
	}
}