// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.util.printing;

import std.stdio;
import std.traits:isUnsigned;

import lanlib.util.array : indexOf;

void printT(T)(string format, T val) @nogc nothrow
{
	string s = _printT(format, val);
	print(s);
}

void printT(T, A...)(string format, T val, A args) @nogc nothrow
{
	string newFormat = _printT(format, val);
	printT(newFormat, args);
}

private string _printT(T)(string format, T val) @nogc nothrow
{
	foreach(i, ch; format)
	{
		if(ch == '%')
		{
			val.print();
			return format[i+1..$];
		}
		printf("%c", ch);
	}
	val.print();
	return "";
}

void print(char ch) @nogc nothrow
{
	printf("%c", ch);
}

void print(string val) @nogc nothrow
{
	foreach(ch; val)
	{
		printf("%c", ch);
	}
}

void print(double val) @nogc nothrow
{
	printf("%f", val);
}

void print(long val) @nogc nothrow
{
	printf("%d", val);
}

void print(T)(T val) @nogc nothrow
if(isUnsigned!T)
{
	printf("%u", cast(ulong)val);
}

void print(bool val) @nogc nothrow
{
	if(val)
	{
		printf("true");
	}
	else
	{
		printf("false");
	}
}