// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module math.transform;

import math.matrix;
import math.vector;


struct Transform
{
	private Mat4 _matrix;
	private Vec3 _position;
	private Vec3 _scale;
	private Vec3 _rotation;

	this(float scale, Vec3 position)
	{
		_scale = Vec3(scale);
		_position = position;
		_rotation = Vec3(0,0,0);
		compute_matrix();
	}

	void compute_matrix()
	{
		_matrix.set([
			[_scale.x, 0.0f,     0.0f,     0],
			[0.0f,     _scale.y, 0.0f,     0],
			[0.0f,     0.0f,     _scale.z, 0],
			[_position.x, _position.y, _position.z, 1.0f]
		]);
	}

	@property ref Mat4 matrix()
	{
		compute_matrix();
		return _matrix;
	}

	void scale(float s)
	{
		_scale.x = s;
		_scale.y = s;
		_scale.z = s;
	}

	void translate(Vec3 v)
	{
		_position.x += v.x;
		_position.y += v.y;
		_position.z += v.z;
	}
}