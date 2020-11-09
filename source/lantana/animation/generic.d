// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.animation.generic;

struct AnimationTrack(Type)
	if(__traits(compiles, {Type t = interpolate(Type.init, Type.init, 0.5f);}))
{
	Type[] keys;
	float[] times;
}
