// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.math.vector;

import std.math;

import lanlib.math.matrix;

alias Vec2 = Vector!(float, 2);
alias Vec3 = Vector!(float, 3);
alias Vec4 = Vector!(float, 4);

struct Vector(T, uint Size)
{
	static assert(Size > 0);
	T[Size] data;

	@nogc @safe this(const T[Size] d)
	{
		data = d;
	}
	@nogc @safe this(const T val)
	{
		static foreach(uint i; 0..Size)
		{
			data[i] = val;
		}
	}

	@nogc @safe @property const double length_squared()
	{
		T l_sq = 0;
		static foreach(uint i; 0..Size)
		{
			l_sq += data[i]*data[i];
		}
		return l_sq;
	}

	@nogc @safe @property const double length()
	{
		return sqrt(length_squared);
	}

	@nogc @safe void normalize()
	{
		T len = cast(T)length;
		static foreach(uint i; 0..Size)
		{
			data[i] /= len;
		}
	}

	@nogc @safe @property T *ptr()
	{
		return &data[0];
	}

	@nogc @safe @property const uint bytesize()
	{
		return Size*T.sizeof;
	}

	@nogc @safe @property ref T x() {
		return data[0];
	}

	@nogc @safe @property ref T r() {
		return data[0];
	}

	@nogc @safe @property const T x() {
		return data[0];
	}

	@nogc @safe @property const T r() {
		return data[0];
	}

	static if (Size >= 2)
	{
		@nogc @safe @property ref T y() {
			return data[1];
		}

		@nogc @safe @property ref T g() {
			return data[1];
		}

		@nogc @safe @property const T y() {
			return data[1];
		}

		@nogc @safe @property const T g() {
			return data[1];
		}

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
		@nogc @safe @property ref T z()
		{
			return data[2];
		}

		@nogc @safe @property ref T b()
		{
			return data[2];
		}

		@nogc @safe @property const T z()
		{
			return data[2];
		}

		@nogc @safe @property const T b()
		{
			return data[2];
		}

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
		@nogc @safe @property ref T w()
		{
			return data[3];
		}

		@nogc @safe @property ref T a()
		{
			return data[3];
		}

		@nogc @safe @property const T w()
		{
			return data[3];
		}

		@nogc @safe @property const T a()
		{
			return data[3];
		}

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

	@nogc @safe const Vector!(T, Size) opBinary(string op)(const T val)
	{
		auto v = Vector!(T, Size)();
		static foreach(uint i; 0..Size)
		{
			static if(op == "*")
			{
				v.data[i] = data[i]*val;
			}
			else static if(op == "/")
			{
				v.data[i] = data[i]/val;
			}
			else static assert(false, "Operator not supported for vectors and scalars: "~op);
		}
		return v;
	}

	@nogc @safe const Vector!(T, Size) opBinary(string op)(const Vector!(T, Size) rhs)
	{
		auto v = Vector!(T, Size)();
		static foreach(uint i; 0..Size)
		{
			static if(op == "+")
			{
				v.data[i] = data[i] + rhs.data[i];
			}
			else static if(op == "-")
			{
				v.data[i] = data[i] - rhs.data[i];
			}
			else
			{
				static assert(false, "Operator not supported between vectors: "~op);
			}
		}
	}

	@nogc @safe const Vector!(T, Column) mult(uint Column)(Matrix!(T, Size, Column) mat)
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

	@nogc @safe const T dot(Vector!(T, Size) rhs)
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
		@nogc @safe Vector!(T, Size) cross(Vector!(T, Size) rhs)
		{
			return(Vector!(T, Size)(
				y*rhs.z - z*rhs.y,
				-(x*rhs.z - z*rhs.x),
				x*rhs.y - y*rhs.x)
			);
		}
	}

	@nogc @safe ref T opIndex(uint ind)
	{
		return data[ind];
	}

	@nogc @safe const T opIndex(uint ind)
	{
		return data[ind];
	}

	@nogc @safe const bool opEquals()(auto ref const Vector!(T, Size) rhs)
	{
		bool result = true;
		static foreach(uint i; 0..Size)
		{
			result = result && (data[i] == rhs.data[i]);
		}
		return result;
	}
}