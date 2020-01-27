// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.util.files;

import std.conv : emplace;
import std.file;
import std.meta;
import std.stdio;
import std.traits;

import gl3n.linalg;

import lanlib.util.memory;
import logic;
import lanlib.math;
import lanlib.types;
import lanlib.util.array;
import render;


enum isSimpleType(Type) = isBasicType!Type || isStaticArray!Type;
enum isDumbData(Type) = isSimpleType!Type || allSatisfy!(isSimpleType, Fields!Type);

private struct BinaryDescriptor(Type)
	if(isDumbData!Type)
{
	alias BinType = Unqual!Type;
	BinType base;

	this(Type p_base, ref ubyte[] p_buffer)
	{
		base = cast(BinType) p_base;
	}

	Type getData(ref ubyte[] p_buffer)
	{
		return cast(Type) base;
	}

}

private struct BinaryDescriptor(Type)
	if(isPointer!Type)
{
	alias BinType = BinaryDescriptor!(PointerTarget!Type);

	ulong byteOffset;
	this(Type p_base, ref ubyte[] p_buffer)
	{
		byteOffset = p_buffer.length;
		p_buffer.length += BinType.sizeof;

		BinType* ptr = cast(BinType*) &p_buffer[byteOffset];
		emplace!BinType(ptr, *p_base, p_buffer);
	}

	Type getData(ref ubyte[] p_buffer)
	{
		return cast(Type)(&p_buffer[byteOffset]);
	}
}

private struct BinaryDescriptor(Type)
	if(isDynamicArray!Type)
{
	alias SubType = Unqual!(ForeachType!Type);
	static if(isDumbData!SubType)
	{
		alias BinType = SubType;
	}
	else
	{
		alias BinType = BinaryDescriptor!SubType;
	}
	uint count;
	uint byteOffset;

	this(Type p_array, ref ubyte[] p_buffer)
	{
		//writeln("Dynamic array: ", p_array);
		count = cast(uint)p_array.length;
		byteOffset = cast(uint)p_buffer.length;

		if(p_array.length == 0)
		{
			return;
		}

		p_buffer.length += count*BinType.sizeof;
		static if(isDumbData!SubType)
		{
			SubType* data = cast(SubType*)(&p_buffer[byteOffset]);
			data[0..count] = p_array[0..count];
		}
		else foreach(i; 0..count)
		{
			auto ptr = cast(BinType*)&p_buffer[byteOffset + i*BinType.sizeof];
			emplace!BinType(ptr, p_array[i], p_buffer);
		}
	}

	Type getData(ref ubyte[] p_buffer)
	{
		SubType[] array = new SubType[count];
		BinType[] binArray = (cast(BinType*)&p_buffer[byteOffset])[0..count];

		static if(isDumbData!SubType)
		{
			array[0..count] = binArray[0..count];
		}
		else foreach(i, ref bin; binArray)
		{
			array[i] = binArray[i].getData(p_buffer);
		}
		return cast(Type) array;
	}
}

private template Declare(Type, string name)
{
	static if(isDumbData!Type)
	{
		enum Declare = Type.stringof~" "~name~";\n";
	}
	else
	{
		enum Declare = "BinaryDescriptor!("~Type.stringof~") "~name~";\n";
	}
}

private template BaseAssign(Type, string base, string field)
{
	static if(isDumbData!Type)
	{
		enum BaseAssign = base~"."~field~" = "~field~";\n";
	}
	else
	{
		enum BaseAssign = base~"."~field~" = "~field~".getData(p_buffer);";
	}
}

private template FieldAssign(Type, string field)
{
	static if(isDumbData!Type)
	{
		enum FieldAssign = field~"= p_base."~field~";";
	}
	else
	{
		enum FieldAssign = field~" = BinaryDescriptor!("~Type.stringof~")(p_base."~field~", p_buffer);";
	}
}

// Struct for loading and storing complex data from a byte buffers without pointers
private struct BinaryDescriptor(Type)
	if(is(Type == struct) && !isDumbData!Type)
{
	enum fieldNames = FieldNameTuple!Type;

	static foreach(i, type; Fields!Type)
	{
		//pragma(msg, Declare!(type, fieldNames[i].stringof[1..$-1]));
		mixin(Declare!(type, fieldNames[i].stringof[1..$-1]));
	}

	this(Type p_base, ref ubyte[] p_buffer)
	{
		static foreach(i, type; Fields!Type)
		{
			//pragma(msg, FieldAssign!(type, fieldNames[i].stringof[1..$-1]));
			mixin(FieldAssign!(type, fieldNames[i].stringof[1..$-1]));
		}
	}

	Type getData(ref ubyte[] p_buffer)
	{
		Type val;
		static foreach(i, type; Fields!Type)
		{
			//pragma(msg, BaseAssign!(type, val.stringof, fieldNames[i].stringof[1..$-1]));
			mixin(BaseAssign!(type, val.stringof, fieldNames[i].stringof[1..$-1]));
		}
		return val;
	}
}

private struct BinHeader
{
	char[4] magic = "LNT_";
	uint bufferSize;
	uint typeSize;
}

T loadBinary(T)(string p_file)
{
	alias BinType = BinaryDescriptor!T;

	//pragma(msg, FieldNameTuple!BinType);

	auto file = File(p_file, "rb");

	BinHeader[] headerBuffer = new BinHeader[1];
	file.rawRead(headerBuffer);

	BinHeader header = headerBuffer[0]; 

	assert(header.magic == "LNT_", header.magic);
	assert(header.typeSize == BinType.sizeof);
	assert(BinHeader.sizeof + BinType.sizeof + header.bufferSize == file.size);

	BinType[] dataBuffer = new BinType[1];
	file.rawRead(dataBuffer);

	ubyte[] buffer = new ubyte[header.bufferSize];
	if(buffer.length > 0)
	{
		file.rawRead(buffer);
	}
	
	auto data = dataBuffer[0];
	T value = data.getData(buffer);
	return value;
}

void storeBinary(T)(string p_file, auto ref T p_data)
{
	alias BinType = BinaryDescriptor!T;

	ubyte[] buffer;
	BinType data = BinType(p_data, buffer);

	BinHeader header = BinHeader();
	header.typeSize = BinType.sizeof;
	header.bufferSize = cast(uint)buffer.length;

	auto file = File(p_file, "wb");
	file.rawWrite((&header)[0..1]);
	file.rawWrite((&data)[0..1]);
	
	if(buffer.length > 0)
	{
		file.rawWrite(buffer);
	}

	// Text for debug
	//writeln(header);
	//writeln(data);
}