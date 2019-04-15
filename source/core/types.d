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

struct Transform
{
	Mat4 matrix;
	this(float[4][4] matrix)
	{
		this.matrix = Mat4(matrix); 
	}

	@property float pos_x()
	{
		return matrix[3][0];
	}
	@property float pos_y()
	{
		return matrix[3][1];
	}
	@property float pos_z()
	{
		return matrix[3][2];
	}

	@property void pos_x(float val)
	{
		matrix[3][0] = val;
	}
	@property void pos_y(float val)
	{
		matrix[3][1] = val;
	}
	@property void pos_z(float val)
	{
		matrix[3][2] = val;
	}

	void scale(float scale)
	{
		matrix[0][0] = scale;
		matrix[1][1] = scale;
		matrix[2][2] = scale;
	}

	void scale(Vec3 scale)
	{
		matrix[0][0] = scale.x;
		matrix[1][1] = scale.y;
		matrix[2][2] = scale.z;
	}

	void translate(Vec3 direction)
	{
		matrix[3][0] += direction.x;
		matrix[3][1] += direction.y;
		matrix[3][2] += direction.z;
	}
}

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

	@property const T x() {
		return data[0];
	}

	@property const T r() {
		return data[0];
	}

	@property void x(T val) {
		data[0] = val;
	}

	@property void r(T val) {
		data[0] = val;
	}

	static if (Size >= 2)
	{
		@property const T y() {
			return data[1];
		}

		@property const T g() {
			return data[1];
		}

		@property void y(T val) {
			data[1] = val;
		}

		@property void g(T val) {
			data[1] = val;
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
		@property const T z()
		{
			return data[2];
		}

		@property const T b()
		{
			return data[2];
		}

		@property void z(T val)
		{
			data[2] = val;
		}

		@property void b(T val)
		{
			data[2] = val;
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
		@property const T w()
		{
			return data[3];
		}

		@property const T a()
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