// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.types.transform;

import std.math: sin, cos;

import lanlib.types.func;
import lanlib.types.matrix;
import lanlib.types.vector;

struct Transform
{
	private Mat4 _matrix;
	// X Y and Z rotations in degrees
	private Vec3 _rotation;
	private Vec3 _position;
	private Vec3 _scale;

	this(const float scale, const Vec3 position) @nogc @safe nothrow
	{
		_scale = Vec3(scale);
		_position = position;
		_rotation = Vec3(0,0,0);
		compute_matrix();
	}

	void compute_matrix() @nogc @safe nothrow
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

	@property ref Mat4 matrix() @nogc @safe nothrow
	{
		compute_matrix();
		return _matrix;
	}

	void scale(const float s) @nogc @safe nothrow
	{
		_scale.x = s;
		_scale.y = s;
		_scale.z = s;
	}

	void scale(const Vec3 scale) @nogc @safe nothrow
	{
		_scale = scale;
	}

	void translate(const Vec3 v) @nogc @safe nothrow
	{
		_position.x += v.x;
		_position.y += v.y;
		_position.z += v.z;
	}

	void rotate_degrees(float x, float y, float z) @nogc @safe nothrow
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

	Mat4 rotation_matrix() @nogc @safe nothrow
	{
		float sx, sy, sz;
		float cx, cy, cz;
		sincos(radians(_rotation.x), sx, cx);
		sincos(radians(_rotation.y), sy, cy);
		sincos(radians(_rotation.z), sz, cz);

		return Mat4([
			[cy*cz,   sx*sy*cz - cx*sz, sx*sz + cx*sy*cz, 0f],
			[cy*sz,   cx*cz + sx*sy*sz, cx*sy*sz - sx*cz, 0f],
			[  -sy,              sx*cy,            cx*cy, 0f],
			[    0,                  0,                0, 1f]
		]);
	}

	//@nogc @safe const Vec3 forward()
	//{
	//	float sx, sy, cx, cy;

	//	sincos( radians( _rotation.x ), sx, cx );
	//	sincos( radians( _rotation.y ), sy, cy );

	//	return Vec3( ... );
	//}
}