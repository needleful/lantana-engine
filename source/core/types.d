// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module core.types;

alias Vec2 = Vector!(float, 2);
alias Vec3 = Vector!(float, 3);
alias Vec4 = Vector!(float, 4);

alias Mat2 = Matrix!(float, 2, 2);
alias Mat3 = Matrix!(float, 3, 3);
alias Mat4 = Matrix!(float, 4, 4);

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
	@property T *bytes()
	{
		return data.ptr;
	}

	@property const uint bytesize()
	{
		return Size*T.sizeof;
	}

	@property T x() {
		return data[0];
	}

	@property T r() {
		return data[0];
	}

	static if (Size >= 2)
	{
		@property T y() {
			return data[1];
		}

		@property T g() {
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
		@property T z()
		{
			return data[2];
		}

		@property T b()
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
		@property T w()
		{
			return data[3];
		}

		@property T a()
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

struct Matrix(T, uint Rows, uint Columns)
{
	Vector!(T, Columns)[Rows] data;

	this(T[Rows][Columns] input)
	{
		static foreach(int i; 0..Rows)
		{
			data[i] = Vector!(T, Columns)(input[i]);
		}
	}

	@property T *bytes()
	{
		return data[0].bytes;
	}

	ref T opIndex(uint i, uint j)
	{
		assert(i < Rows && j < Columns);
		return data[i][j];
	}

	ref Vector!(T, Columns) opIndex(int i)
	{
		assert(i < Rows);
		return data[i];
	}
}