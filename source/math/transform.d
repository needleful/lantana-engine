// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module math.transform;

import std.math : PI;

import math.angles;
import math.matrix;
import math.vector;


struct Transform
{
	private Mat4 _matrix;
	private Vec3 _position;
	private Vec3 _scale;
	private Angles _angles;

	@nogc this(const float scale, const Vec3 position)
	{
		_scale = Vec3(scale);
		_position = position;
		_angles = Angles(Vec3(0, 1, 0), 0);
		compute_matrix();
	}

	@nogc void compute_matrix()
	{
		_matrix.set([
			[_scale.x, 0.0f,     0.0f,     0],
			[0.0f,     _scale.y, 0.0f,     0],
			[0.0f,     0.0f,     _scale.z, 0],
			[0.0f,     0.0f,     0.0f,  1.0f]
		]);
		_matrix *= _angles.to_matrix();
		_matrix[3, 0] = _position.x;
		_matrix[3, 1] = _position.y;
		_matrix[3, 2] = _position.z;
	}

	@nogc @property ref Mat4 matrix()
	{
		compute_matrix();
		return _matrix;
	}

	@nogc void scale(const float s)
	{
		_scale.x = s;
		_scale.y = s;
		_scale.z = s;
	}

	@nogc void scale(const Vec3 scale)
	{
		_scale = scale;
	}

	@nogc void translate(const Vec3 v)
	{
		_position.x += v.x;
		_position.y += v.y;
		_position.z += v.z;
	}

	@nogc void rotate_radians(const float rad)
	{
		_angles.rotate(rad);
	}

	@nogc void rotate_degrees(const float deg)
	{
		_angles.rotate((deg/180.0) * PI);
	}
}