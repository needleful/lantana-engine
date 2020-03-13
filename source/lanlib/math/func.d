// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.math.func;

public import std.math: sin, cos, tan, PI;
import gl3n.linalg: quat;

double radians(double p_degrees)  @safe nothrow
{
	return (p_degrees/180)*PI;
}

void sincos(float p_radians, ref float s, ref float c)  @safe nothrow
{
	s = sin(p_radians);
	c = cos(p_radians);
}

public uint max(uint a, uint b)  nothrow
{
	return a > b? a : b;
}

public quat qlerp(quat a, quat b, float t)  nothrow
{
    float dot = a.w * b.w + a.x * b.x + a.y * b.y + a.z * b.z;

    quat result;
    if(dot < 0) { // Determine the "shortest route"...
        result = a - (b + a) * t; // use -b instead of b
    } else {
        result = a + (b - a) * t;
    }
    result.normalize();

    return result;
}