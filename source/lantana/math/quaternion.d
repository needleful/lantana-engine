

module lantana.math.quaternion;

import lantana.math.matrix;

struct Quat {
	float[4] data;

	this(float x, float y, float z, float w) {
		data = [x, y, z, w];
	}

	static Quat identity() {
		return Quat(0, 0, 0, 1);
	}

	Mat4 matrix() pure {
		return Mat4([
			[w, -x, -y, -z],
			[x,  w, -z,  y],
			[y,  z,  w, -x],
			[z, -y,  x,  w]
		]);
	}

	float dot(ref Quat rhs) pure nothrow {
		float sum = 0;
		static foreach(int i; 0..4) {
			sum += data[i] * rhs.data[i];
		}
		return sum;
	}

	Quat opBinary(string op)(Quat rhs) pure {
		Quat newQ;
		static foreach(int i; 0..4) {
			mixin("newQ.data[i] = data[i]" ~ op ~ " rhs.data[i];");
		}
		return newQ;
	}

	Quat opBinary(string op)(double scal) pure {
		Quat newQ;
		static foreach(int i; 0..4) {
			mixin("newQ.data[i] = data[i]"~op~"scal;");
		}
		return newQ;
	}

	float length() nothrow {
		import std.math: sqrt;
		return sqrt(dot(this));
	}

	void normalize() nothrow{
		float l = length();
		foreach(ref float d; data) {
			d /= l;
		}
	}

	@property ref float x() pure return {
		return data[0];
	}
	@property ref float y() pure return {
		return data[1];
	}
	@property ref float z() pure return {
		return data[2];
	}
	@property ref float w() pure return {
		return data[3];
	}
}