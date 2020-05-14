// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.file.lgbt;

import std.conv : emplace;
import std.file;
import std.meta;
import std.stdio;
import std.string;
import std.traits;

import lantana.types.memory;
import lantana.types.meta;

struct GenericBinaryType(Type)
	if(isDumbData!Type)
{
	static foreach(subType; Fields!Type)
	{
		mixin Import!subType;
	}
	alias BinType = Unqual!Type;
	BinType base;

	this(Type p_base, ref ubyte[] _)
	{
		base = cast(BinType) p_base;
	}

	Type getData(ref ubyte[] _)
	{
		return cast(Type) base;
	}

	Type getData(ref ubyte[] _, ref Region _)
	{
		return cast(Type) base;
	}

}

struct GenericBinaryType(Type)
	if(isPointer!Type)
{
	alias SubType = PointerTarget!Type;
	alias BinType = GenericBinaryType!(Unqual!SubType);

	ulong byteOffset;
	this(Type p_base, ref ubyte[] p_buffer)
	{
		static if(isDumbData!SubType)
		{
			SubType[] data = p_buffer.addSpace!SubType(1, byteOffset);
			emplace!SubType(data.ptr, *p_base);
		}
		else
		{
			BinType[] data = p_buffer.addSpace!BinType(1, byteOffset);
			emplace!BinType(data.ptr, *p_base, p_buffer);
		}
	}

	Type getData(ref ubyte[] p_buffer)
	{
		static if(isDumbData!SubType)
		{
			auto ptr = cast(Type)(&p_buffer[byteOffset]);
			return ptr;
		}
		else
		{
			BinType* data = cast(BinType*)&p_buffer[byteOffset];
			return &data.getData(p_buffer);
		}
	}

	Type getData(ref ubyte[] p_buffer, ref Region p_alloc)
	{
		// Assumes that the buffer will be put on p_alloc
		static if(isDumbData!SubType)
		{
			return cast(Type)(&p_buffer[byteOffset]);
		}
		else
		{
			BinType* data = cast(BinType*)&p_buffer[byteOffset];
			return cast(Type) p_alloc.make!SubType(data.getData(p_buffer, p_alloc));
		}
	}
}

struct GenericBinaryType(Type)
	if(isDynamicArray!Type)
{
	alias SubType = ForeachType!Type;

	static if(isDumbData!SubType)
	{
		alias BinType = Unqual!SubType;
	}
	else
	{
		alias BinType = GenericBinaryType!SubType;
	}

	uint count;
	uint byteOffset;

	this(Type p_array, ref ubyte[] p_buffer)
	{
		if(p_array.length == 0)
		{
			return;
		}

		count = cast(uint) p_array.length;
		ulong off;
		BinType[] buffer = p_buffer.addSpace!BinType(p_array.length, off);
		byteOffset = cast(uint) off;

		static if(isDumbData!SubType)
		{
			buffer.readData(p_array);
		}
		else 
		{
			// Just assigning or emplacing the data doesn't work, so we have to do some wild bit-twiddling
			BinType[] temp_buffer;
			temp_buffer.reserve(count);
			foreach(elem; p_array)
			{
				temp_buffer ~= BinType(elem, p_buffer);
			}
			auto byteSize = count*BinType.sizeof;
			auto byteEnd = byteOffset + byteSize;
			p_buffer[byteOffset..byteEnd] = (cast(ubyte*)temp_buffer.ptr)[0..byteSize];
		}
	}

	Type getData(ref ubyte[] p_buffer)
	{
		BinType[] binArray = p_buffer.readArray!BinType(byteOffset, count);

		static if(isDumbData!SubType)
		{
			return cast(Type) binArray.dup();
		}
		else 
		{
			SubType[] array = new SubType[count];
			foreach(i, bin; binArray)
			{
				array[i] = binArray[i].getData(p_buffer);
			}
			return cast(Type) array;
		}
	}

	Type getData(ref ubyte[] p_buffer, ref Region p_alloc)
	{
		if(count == 0)
		{
			return cast(Type) [];
		}

		auto binArray = p_buffer.readArray!BinType(byteOffset, count);

		static if(isDumbData!SubType)
		{
			auto array = p_alloc.makeList!BinType(count);
			array.readData(binArray);
			return cast(Type) array;
		}
		else
		{
			auto array = p_alloc.makeList!SubType(count);
			foreach(i, ref bin; binArray)
			{
				array[i] = binArray[i].getData(p_buffer, p_alloc);
			}
			return cast(Type) array;
		}
	}
}

template Declare(Type, string name)
{
	static if(isDumbData!Type)
	{
		enum Declare = Type.stringof~" "~name~";";
	}
	else
	{
		enum Declare = "GenericBinaryType!("~Type.stringof~") "~name~";";
	}
}

template BaseAssign(Type, string base, string field)
{
	static if(isDumbData!Type)
	{
		enum BaseAssign = base~"."~field~" = "~field~";";
	}
	else
	{
		enum BaseAssign = base~"."~field~" = "~field~".getData(p_buffer);";
	}
}

template BaseAssignAlloc(Type, string base, string field)
{
	static if(isDumbData!Type)
	{
		enum BaseAssignAlloc = base~"."~field~" = "~field~";";
	}
	else
	{
		enum BaseAssignAlloc = base~"."~field~" = "~field~".getData(p_buffer, p_alloc);";
	}
}

template FieldAssign(Type, string field)
{
	static if(isDumbData!Type)
	{
		enum FieldAssign = field~"= p_base."~field~";";
	}
	else 
	{
		enum FieldAssign = field~" = GenericBinaryType!("~Type.stringof~")(p_base."~field~", p_buffer);";
	}
}

// Struct for loading and storing complex data from a byte buffers without pointers
struct GenericBinaryType(Type)
	if(is(Type == struct) && !isDumbData!Type)
{
	alias valType = Type;
	enum fieldNames = FieldNameTuple!Type;

	static foreach(i, type; Fields!Type)
	{
		mixin Import!type;
		mixin(Declare!(type, fieldNames[i].stringof[1..$-1]));
	}

	this(Type p_base, ref ubyte[] p_buffer)
	{
		static foreach(i, type; Fields!Type)
		{
			mixin(FieldAssign!(type, fieldNames[i].stringof[1..$-1]));
		}
	}

	Type getData(ref ubyte[] p_buffer)
	{
		Type val;
		static foreach(i, type; Fields!Type)
		{
			mixin(BaseAssign!(type, val.stringof, fieldNames[i].stringof[1..$-1]));
		}
		return val;
	}

	Type getData(ref ubyte[] p_buffer, ref Region p_alloc)
	{
		Type val;
		static foreach(i, type; Fields!Type)
		{
			mixin(BaseAssignAlloc!(type, val.stringof, fieldNames[i].stringof[1..$-1]));
		}
		return val;
	}
}

struct BinaryHeader
{
	char[4] magic = "LGBT";
	uint bufferSize;
	uint typeSize;
}

T binaryLoad(T)(string p_file, ref Region p_alloc) @nogc
{
	void readValue(Type)(FILE* p_file, Type* p_ptr, size_t p_count = 1) @nogc
	{
		auto size = fread(cast(void*) p_ptr, Type.sizeof, p_count, p_file);
		assert(size == p_count);
	}

	alias BinType = GenericBinaryType!T;

	// creating a z-terminated string in the region
	string fileZ = p_alloc.copy(p_file);
	p_alloc.make!char('\0');

	FILE* file = fopen(fileZ.ptr, "rb");
	if(file == null)
	{
		printf("Missing file: %s\n", fileZ.ptr);
		debug assert(false, p_file);
		else return T.init;
	}

	scope(exit) fclose(file);

	int fsize;
	fseek(file, 0, SEEK_END);
	fsize = ftell(file);
	rewind(file);

	BinaryHeader header;
	readValue!BinaryHeader(file, &header);

	assert(header.magic == "LGBT", header.magic);
	assert(header.typeSize == BinType.sizeof, p_file);
	assert(BinaryHeader.sizeof + BinType.sizeof + header.bufferSize == fsize, p_file);

	BinType data;
	readValue!BinType(file, &data);

	ubyte[] buffer = p_alloc.makeList!ubyte(header.bufferSize);
	if(buffer.length > 0)
	{
		readValue!ubyte(file, buffer.ptr, buffer.length);
	}
	
	return data.getData(buffer, p_alloc);
}

T binaryLoad(T)(string p_file)
{
	alias BinType = GenericBinaryType!T;

	//pragma(msg, FieldNameTuple!BinType);

	if(!p_file.exists())
	{
		writeln("File does not exist: ", p_file);
		debug assert(false, p_file);
		else return T.init;
	}

	auto file = File(p_file, "rb");

	BinaryHeader[] headerBuffer = new BinaryHeader[1];
	file.rawRead(headerBuffer);

	BinaryHeader header = headerBuffer[0]; 

	assert(header.magic == "LGBT", header.magic);
	assert(header.typeSize == BinType.sizeof, p_file);
	assert(BinaryHeader.sizeof + BinType.sizeof + header.bufferSize == file.size, p_file);

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

void binaryStore(T)(string p_file, auto ref T p_data)
{
	alias BinType = GenericBinaryType!T;

	ubyte[] buffer;
	buffer.reserve(ushort.max);
	BinType data = BinType(p_data, buffer);

	BinaryHeader header = BinaryHeader();
	header.typeSize = BinType.sizeof;
	header.bufferSize = cast(uint)buffer.length;
	
	auto file = File(p_file, "wb");
	file.rawWrite((&header)[0..1]);
	file.rawWrite((&data)[0..1]);
	
	if(buffer.length > 0)
	{
		file.rawWrite(buffer);
	}
}