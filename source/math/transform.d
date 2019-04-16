// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module math.transform;

import math.matrix;
import math.quaternion;
import math.vector;


struct Transform
{
	private Mat4 _matrix;
	private Vec3 _position;
	private Vec3 _scale;
	private Quat _rotation;

	this(float scale, Vec3 position)
	{
		_scale = Vec3(scale);
		_position = position;
		_rotation = Quat(0,-1,0.2,0.2);
		compute_matrix();
	}

	void compute_matrix()
	{
		_matrix.set([
			[_scale.x, 0.0f,     0.0f,     0],
			[0.0f,     _scale.y, 0.0f,     0],
			[0.0f,     0.0f,     _scale.z, 0],
			[0.0f,     0.0f,     0.0f,   1.0f]
		]);
		_matrix *= _rotation.to_matrix();
		_matrix[3, 0] = _position.x;
		_matrix[3, 1] = _position.y;
		_matrix[3, 2] = _position.z;
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