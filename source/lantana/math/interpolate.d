// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.math.interpolate;

import gl3n.linalg;
import gl3n.interpolate;

public quat interpolate(quat a, quat b, float t) @safe @nogc nothrow
{
    float dot = a.w * b.w + a.x * b.x + a.y * b.y + a.z * b.z;

    quat result;

    if(dot < 0) // Determine the "shortest route"
        result = a - (b + a) * t; // use -b instead of b
    else
        result = a + (b - a) * t;

    result.normalize();

    return result;
}

public Type interpolate(Type)(Type a, Type b, float t) @safe @nogc nothrow
	if(__traits(compiles, {Type c = a.lerp(b, t);} ))
{
	return a.lerp(b, t);
}