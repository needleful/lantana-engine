// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module math.matrix;

alias Mat2 = Matrix!(float, 2, 2);
alias Mat3 = Matrix!(float, 3, 3);
alias Mat4 = Matrix!(float, 4, 4);

struct Matrix(T, uint Rows, uint Columns)
{
	T[Rows][Columns] data;

	this(T[Rows][Columns] input)
	{
		static foreach(int i; 0..Rows)
		{
			static foreach(int j; 0..Columns)
			{
				data[i][j] = input[i][j];
			}
		}
	}

	void set(T[Rows][Columns] input)
	{
		static foreach(int i; 0..Rows)
		{
			static foreach(int j; 0..Columns)
			{
				data[i][j] = input[i][j];
			}
		}
	}

	@property T *ptr()
	{
		return data[0].ptr;
	}

	ref T opIndex(uint i, uint j)
	{
		assert(i < Rows && j < Columns);
		return data[i][j];
	}

	const T opIndex(uint i, uint j)
	{
		assert(i < Rows && j < Columns);
		return data[i][j];
	}

	static if(Rows == Columns)
	{
		void opMulAssign(const Matrix!(T, Rows, Columns) rhs)
		{
			T[Rows][Columns] d;
			static foreach(uint i; 0..Rows)
			{
				static foreach(uint j; 0..Columns)
				{
					d[i][j] = 0;
					static foreach(uint k; 0..Columns)
					{
						d[i][j] += this[i, k] * rhs[k, j];
					}
				}
			}
			set(d);
		}
	}
}