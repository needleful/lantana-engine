// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.types.func;

public import std.math: sin, cos, tan, PI;

float radians(float degrees) @nogc @safe nothrow
{
	return (degrees/180)*PI;
}

void sincos(float radians, ref float s, ref float c) @nogc @safe nothrow
{
	s = sin(radians);
	c = cos(radians);
}