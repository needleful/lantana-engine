// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module math.quaternion;

import math.matrix;

struct Quat
{
	float x, y, z, w;

	this(float x, float y, float z, float w)
	{
		this.x = x;
		this.y = y;
		this.z = z;
		this.w = w;
	}

	// Returns a row-major transformation matrix
	Mat4 to_matrix()
	{
		float x2 = x + x;
		float y2 = y + y;
		float z2 = z + z;

		float xx = x * x2;
		float xy = x * y2;
		float xz = x * z2;

		float yy = y * y2;
		float yz = y * z2;
		float zz = z * z2;

		float wx = w * x2;
		float wy = w * y2;
		float wz = w * z2;

		return Mat4([
			[1.0f - (yy+zz), xy+wz         , xz-wy          , 0.0f],
			[xy-wz         , 1.0f - (xx+zz), yz+wx          , 0.0f],
			[xz+wy         , yz-wx         , 1.0f - (xx+yy) , 0.0f],
			[0.0f          , 0.0f          , 0.0f           , 1.0f]
		]);
	}
}