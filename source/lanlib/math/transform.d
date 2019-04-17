// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.math.transform;

import std.math: sin, cos, PI;

import lanlib.math.matrix;
import lanlib.math.vector;

struct Transform
{
	private Mat4 _matrix;
	private Mat4 _rotation;
	private Vec3 _position;
	private Vec3 _scale;

	@nogc @safe this(const float scale, const Vec3 position)
	{
		_scale = Vec3(scale);
		_position = position;
		_rotation = Mat4_Identity;
		compute_matrix();
	}

	@nogc @safe void compute_matrix()
	{
		_matrix.set([
			[_scale.x, 0.0f,     0.0f,     0],
			[0.0f,     _scale.y, 0.0f,     0],
			[0.0f,     0.0f,     _scale.z, 0],
			[0.0f,     0.0f,     0.0f,  1.0f]
		]);
		_matrix *= _rotation;
		_matrix[3, 0] = _position.x;
		_matrix[3, 1] = _position.y;
		_matrix[3, 2] = _position.z;
	}

	@nogc @safe @property ref Mat4 matrix()
	{
		compute_matrix();
		return _matrix;
	}

	@nogc @safe void scale(const float s)
	{
		_scale.x = s;
		_scale.y = s;
		_scale.z = s;
	}

	@nogc @safe void scale(const Vec3 scale)
	{
		_scale = scale;
	}

	@nogc @safe void translate(const Vec3 v)
	{
		_position.x += v.x;
		_position.y += v.y;
		_position.z += v.z;
	}

	// TODO: more rotation functions!
	@nogc @safe rotate_degrees_x(float degrees)
	{
		float rad = (degrees/180)*PI;
		float c = cos(rad);
		float s = sin(rad);
		Mat4 mat = Mat4([
			[1, 0, 0, 0f],
			[0, c, -s, 0],
			[0, s, c, 0],
			[0, 0, 0, 1f]
		]);
		_rotation*= mat;
	}
	// TODO: more rotation functions!
	@nogc @safe rotate_degrees_y(float degrees)
	{
		float rad = (degrees/180)*PI;
		float c = cos(rad);
		float s = sin(rad);
		Mat4 mat = Mat4([
			[c, 0, -s, 0],
			[0, 1, 0, 0f],
			[s, 0, c, 0],
			[0, 0, 0, 1f]
		]);
		_rotation *= mat;
	}
	// TODO: more rotation functions!
	@nogc @safe rotate_degrees_z(float degrees)
	{
		float rad = (degrees/180)*PI;
		float c = cos(rad);
		float s = sin(rad);
		Mat4 mat = Mat4([
			[c, -s, 0, 0],
			[s, c, 0, 0],
			[0, 0, 1, 0f],
			[0, 0, 0, 1f]
		]);
		_rotation*= mat;
	}

	@nogc @safe rotate_degrees_axis(float degrees, const Vec3 axis)
	{
		float rad = (degrees/180)*PI;
		float c = cos(rad);
		float s = sin(rad);

		float x = axis.x;
		float y = axis.y;
		float z = axis.z;

		Mat4 mat = Mat4([
			[  c + (1-c)*x*x, (1-c)*x*y - s*z, (1-c)*x*z + s*y, 0.0f],
			[(1-c)*x*y + s*z,   c + (1-c)*y*y, (1-c)*y*z - s*x, 0.0f],
			[(1-c)*x*z - s*y, (1-c)*y*z + s*x,   c + (1-c)*z*z, 0.0f],
			[           0.0f,            0.0f,            0.0f, 1.0f]
		]);
		_rotation*= mat;
	}

	@nogc @safe rotate_with_matrix(const ref Mat4 mat)
	{
		_rotation *= mat;
	}
}