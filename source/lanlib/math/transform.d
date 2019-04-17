// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.math.transform;

import std.math: sin, cos;

import lanlib.math.func;
import lanlib.math.matrix;
import lanlib.math.vector;

struct Transform
{
	private Mat4 _matrix;
	// X Y and Z rotations in degrees
	private Vec3 _rotation;
	private Vec3 _position;
	private Vec3 _scale;

	@nogc @safe this(const float scale, const Vec3 position)
	{
		_scale = Vec3(scale);
		_position = position;
		_rotation = Vec3(0,0,0);
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
		_matrix *= rotation_matrix();
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

	@nogc @safe void rotate_degrees(float x, float y, float z)
	{
		_rotation.x += x;
		_rotation.y += y;
		_rotation.z += z;

		foreach(ref float angle; _rotation.data)
		{
			while(angle >= 360)
			{
				angle -= 360;
			}
			while(angle <= -360)
			{
				angle += 360;
			}
		}
	}

	@nogc @safe Mat4 rotation_matrix()
	{
		float sx, sy, sz;
		float cx, cy, cz;
		sincos(radians(_rotation.x), sx, cx);
		sincos(radians(_rotation.y), sy, cy);
		sincos(radians(_rotation.z), sz, cz);

		return Mat4([
			[cx*cy,   sz*sx*cy - cz*sy, sz*sy + cz*sx*cy, 0f],
			[cx*sy,   cz*cy + sz*sx*sy, cz*sx*sy - sz*cy, 0f],
			[  -sx,              sz*cx,            cz*cx, 0f],
			[    0,                  0,                0, 1f]
		]);
	}

	@nogc @safe const Vec3 forward()
	{
		float sx, sy, cx, cy;

		sincos( radians( _rotation.x ), sx, cx );
		sincos( radians( _rotation.y ), sy, cy );

		return Vec3( cp * cy, cp * sy, -sp );
	}
}