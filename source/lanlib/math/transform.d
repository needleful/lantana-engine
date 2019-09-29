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
	Mat4 matrix;
	// X Y and Z rotations in degrees
	Vec3 _rotation;
	Vec3 _position;
	Vec3 _scale;

	this(const float scale, const Vec3 position) @nogc @safe nothrow
	{
		_scale = Vec3(scale);
		_position = position;
		_rotation = Vec3(0,0,0);
		compute_matrix();
	}

	void compute_matrix() @nogc @safe nothrow
	{
		matrix.set([
			[_scale.x, 0.0f,     0.0f,     0],
			[0.0f,     _scale.y, 0.0f,     0],
			[0.0f,     0.0f,     _scale.z, 0],
			[0.0f,     0.0f,     0.0f,  1.0f]
		]);
		matrix *= rotation_matrix();
		matrix[0, 3] = _position.x;
		matrix[1, 3] = _position.y;
		matrix[2, 3] = _position.z;
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
			[           cy*cz,            cy*sz,   -sy, 0f],
			[sx*sy*cz - cx*sz, cx*cz + sx*sy*sz, sx*cy, 0f],
			[sx*sz + cx*sy*cz, cx*sy*sz - sx*cz, cx*cy, 0f],
			[0,0,0,1f]
		]);
	}
}