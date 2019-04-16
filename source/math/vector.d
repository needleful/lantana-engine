// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module math.vector;

import std.math;

alias Vec2 = Vector!(float, 2);
alias Vec3 = Vector!(float, 3);
alias Vec4 = Vector!(float, 4);

struct Vector(T, uint Size)
{
	static assert(Size > 0);
	T[Size] data;

	this(T[Size] d)
	{
		data = d;
	}
	this(T val)
	{
		static foreach(uint i; 0..Size)
		{
			data[i] = val;
		}
	}

	@property const T length_squared()
	{
		T l_sq = 0;
		static foreach(uint i; 0..Size)
		{
			l_sq += data[i]*data[i];
		}
		return l_sq;
	}

	@property const T length()
	{
		return sqrt(length_squared);
	}

	void normalize()
	{
		T len = length;
		static foreach(uint i; 0..Size)
		{
			data[i] /= len;
		}
	}

	@property T *ptr()
	{
		return data.ptr;
	}

	@property const uint bytesize()
	{
		return Size*T.sizeof;
	}

	@property ref T x() {
		return data[0];
	}

	@property ref T r() {
		return data[0];
	}

	static if (Size >= 2)
	{
		@property ref T y() {
			return data[1];
		}

		@property ref T g() {
			return data[1];
		}

		static if (Size == 2)
		{
			this(T x, T y)
			{
				data[0] = x;
				data[1] = y;
			}
		}
	}
	static if (Size >= 3)
	{
		@property ref T z()
		{
			return data[2];
		}

		@property ref T b()
		{
			return data[2];
		}

		static if(Size == 3)
		{
			this(T x, T y, T z)
			{
				data[0] = x;
				data[1] = y;
				data[2] = z;
			}
		}
	}
	static if (Size >= 4)
	{
		@property ref T w()
		{
			return data[3];
		}

		@property ref T a()
		{
			return data[3];
		}

		static if(Size == 3)
		{
			this(T x, T y, T z, T w)
			{
				data[0] = x;
				data[1] = y;
				data[2] = z;
				data[3] = w;
			}
		}
	}

	Vector!(T, Size) opBinary(string op)(T val)
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

	Vector!(T, Size) opBinary(string op)(Vector!(T, Size) rhs)
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

	T dot(Vector!(T, Size) rhs)
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
		Vector!(T, Size) cross(Vector!(T, Size) rhs)
		{
			return(Vector!(T, Size)(
				y*rhs.z - z*rhs.y,
				-(x*rhs.z - z*rhs.x),
				x*rhs.y - y*rhs.x)
			);
		}
	}

	ref T opIndex(uint ind)
	{
		return data[ind];
	}

	bool opEquals()(auto ref const Vector!(T, Size) rhs)
	{
		bool result = true;
		static foreach(uint i; 0..Size)
		{
			result = result && (data[i] == rhs.data[i]);
		}
		return result;
	}
}