// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.math.func;

public import std.math: sin, cos, tan, PI;
import lantana.math.quaternion;

double radians(double p_degrees)   nothrow
{
	return (p_degrees/180)*PI;
}

void sincos(float p_radians, ref float s, ref float c)   nothrow
{
	s = sin(p_radians);
	c = cos(p_radians);
}

public T max(T)(T a, T b) nothrow
{
	return a > b? a : b;
}

public T lerp(T)(T a, T b, float t) nothrow {
    return a*(1.0 - t) + b*t;
}

public Quat qlerp(Quat a, Quat b, float t)  nothrow
{
    Quat result;
    if(a.dot(b) < 0) { // Determine the "shortest route"...
        result = a - (b + a) * t; // use -b instead of b
    } else {
        result = a + (b - a) * t;
    }
    result.normalize();

    return result;
}