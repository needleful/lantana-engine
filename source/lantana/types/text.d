// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.types.text;

import std.conv: to;
import std.regex;
import std.traits;

private static auto floatRegex = ctRegex!`-?\d*?\.?\d+`;
private static auto intRegex = ctRegex!`-?\d+`;

public bool convert(S, T)(S text, out T result, T defaultValue = T.init)
	if(isSomeString!S && isFloatingPoint!T)
{
	if(!text.matchFirst(floatRegex))
	{
		result = defaultValue;
		return false;
	}
	else
	{
		return tryConvert(text, result, defaultValue);
	}
}


public bool convert(S, T)(S text, out T result, T defaultValue = T.init)
	if(isSomeString!S && isIntegral!T)
{
	if(!text.matchFirst(intRegex))
	{
		result = defaultValue;
		return false;
	}
	else 
	{
		return tryConvert(text, result, defaultValue);
	}
}

public bool tryConvert(S, T)(S text, out T result, T defaultValue = T.init)
	if(isSomeString!S)
{
	try
	{
		result = text.to!T();
		return true;
	}
	catch (Throwable _)
	{
		result = defaultValue;
		return false;
	}
}