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

	// An alternative to re-creating a matrix
	// not certain if it makes a difference performance-wise,
	// but it feels like it would be faster than making a new matrix
	void update(T[Rows][Columns] input)
	{
		static foreach(int i; 0..Rows)
		{
			static foreach(int j; 0..Columns)
			{
				data[i][j] = input[i][j];
			}
		}
	}

	@property T *bytes()
	{
		return data[0].ptr;
	}

	ref T opIndex(uint i, uint j)
	{
		assert(i < Rows && j < Columns);
		return data[i][j];
	}
}