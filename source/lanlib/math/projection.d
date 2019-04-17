// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.math.projection;

import std.math: tan, PI;

import lanlib.math.matrix;

struct Projection
{
	private Mat4 _matrix;
	float aspect_ratio;
	float fov;
	float near_plane;
	float far_plane;

	@nogc @safe this(float aspect_ratio, float fov, float near_plane, float far_plane)
	{
		this.aspect_ratio = aspect_ratio;
		this.fov = fov;
		this.near_plane = near_plane;
		this.far_plane = far_plane;

		compute_matrix();
	}

	@nogc @safe void compute_matrix()
	{
		float fov_rad = (fov/180)*PI;
		float t = 1.0/tan(fov_rad/2);
		float ar = 1.0/aspect_ratio;

		float z1 = (-near_plane - far_plane)/(near_plane - far_plane);
		float z2 = (2*near_plane*far_plane)/(near_plane - far_plane); 

		_matrix.set([
			[ar*t,  0,  0, 0f],
			[   0,  t,  0, 0f],
			[   0, z1, z2, 0f],
			[   0, 0,   1, 0f]
		]);
	}

	@nogc @safe @property ref Mat4 matrix()
	{
		compute_matrix();
		return _matrix;
	}
}