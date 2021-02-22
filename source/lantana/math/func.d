// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.math.func;

public import std.math: sin, cos, tan, PI;
import gl3n.linalg: quat;

double radians(double p_degrees) @safe @nogc pure nothrow
{
	return (p_degrees/180)*PI;
}

double degrees(double p_radians) @safe @nogc pure nothrow
{
    return(p_radians/PI)*180;
}

void sincos(float p_radians, ref float s, ref float c) @safe @nogc nothrow
{
	s = sin(p_radians);
	c = cos(p_radians);
}

public T max(T)(T a, T b) @safe @nogc pure nothrow
{
	return a > b? a : b;
}

public quat qlerp(quat a, quat b, float t) @safe @nogc pure nothrow
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