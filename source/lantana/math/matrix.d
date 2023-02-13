// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.math.matrix;

alias Mat2 = Matrix!(float, 2, 2);
alias Mat3 = Matrix!(float, 3, 3);
alias Mat4 = Matrix!(float, 4, 4);

alias Mat4x3 = Matrix!(float, 4, 3);

static immutable Mat4 Mat4_Identity = Mat4([
		[1, 0, 0, 0f],
		[0, 1, 0, 0f],
		[0, 0, 1, 0f],
		[0, 0, 0, 1f]
	]);

struct Matrix(T, uint Rows, uint Columns)
{
	static enum rows = Rows;
	static enum columns = Columns;
	alias dataType = T;
	T[Rows][Columns] data;

	this(T[Rows][Columns] input) @nogc @safe nothrow
	{
		data = input;
	}

	void set(T[Rows][Columns] input) @nogc @safe nothrow
	{
		data = input;
	}

	@property T *ptr() @nogc @safe nothrow
	{
		return &data[0][0];
	}

	ref T opIndex(uint i, uint j) @nogc @safe nothrow
	{
		assert(i < Rows && j < Columns);
		return data[i][j];
	}

	const T opIndex(uint i, uint j) @nogc @safe nothrow
	{
		assert(i < Rows && j < Columns);
		return data[i][j];
	}


	const Matrix!(T, Columns, Rows) transposed()  @nogc @safe nothrow {
		Matrix!(T, Columns, Rows) result;
		foreach(uint i; 0..Rows) {
			foreach(uint j; 0..Columns) {
				result[j, i] = this[i, j];
			}
		}
		return result;
	}

	const Matrix!(T, Rows, Columns2) opBinary(string op, uint Columns2)(auto ref in Matrix!(T, Columns, Columns2) rhs) @nogc @safe nothrow {
		Matrix!(T, Rows, Columns2) result;
		static foreach(uint i; 0..Rows) {
			static foreach(uint j; 0..Columns2) {
				result[i, j] = 0;
				static foreach(uint k; 0..Columns) {
					result[i, j] += this[i, k] * rhs[k, j];
				}
			}
		}
		return result;
	} 

	static if(Rows == Columns)
	{
		void opOpAssign(string op)(auto ref in Matrix!(T, Rows, Columns) rhs) @nogc @safe nothrow
			if(op == "*")
		{
			Matrix!(T, Rows, Columns) result = this*rhs;
			this.data = result.data;
		}
	}
}