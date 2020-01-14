// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.math.func;

public import std.math: sin, cos, tan, PI;

float radians(float p_degrees) @nogc @safe nothrow
{
	return (p_degrees/180)*PI;
}

void sincos(float p_radians, ref float s, ref float c) @nogc @safe nothrow
{
	s = sin(p_radians);
	c = cos(p_radians);
}

public uint max(uint a, uint b)
{
	return a > b? a : b;
}