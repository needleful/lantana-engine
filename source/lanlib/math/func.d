// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.math.func;

public import std.math: sin, cos, tan, PI;

@safe @nogc float radians(float degrees)
{
	return (degrees/180)*PI;
}

@safe @nogc void sincos(float radians, ref float s, ref float c)
{
	s = sin(radians);
	c = cos(radians);
}