// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.file.lnb;

import std.conv : emplace;
import std.file;
import std.meta;
import std.stdio;
import std.string;
import std.traits;

import lanlib.util.memory;

enum isSimpleType(Type) = isBasicType!Type || isStaticArray!Type;
enum isSimpleStruct(Type) = isSimpleType!Type || allSatisfy!(isSimpleType, Fields!Type);
enum isDumbData(Type) = isSimpleStruct!Type || allSatisfy!(isSimpleStruct, Fields!Type);

template StripType(T)
{
	static if(isArray!T)
	{
		alias subType = ForeachType!T;
	}
	else static if(isPointer!T)
	{
		alias subType = PointerTarget!T;
	}
	else
	{
		alias subType = T;
	}
	alias StripType = Unqual!subType;
}

mixin template Import(Type)
{
	alias absType = StripType!Type;

	static if(__traits(compiles, moduleName!absType))
	{
		alias templateName = TemplateOf!absType;
		static if(is(templateName == void))
		{
			alias toImport = absType;
		}
		else
		{
			alias toImport = templateName;
		}
		alias pkg = moduleName!toImport;
		mixin("import "~pkg~": "~toImport.stringof.split("(")[0]~";\n");
	}
}

struct LNBDescriptor(Type)
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

struct LNBDescriptor(Type)
	if(isPointer!Type)
{
	alias SubType = PointerTarget!Type;
	alias BinType = LNBDescriptor!(Unqual!SubType);

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

struct LNBDescriptor(Type)
	if(isDynamicArray!Type)
{
	alias SubType = ForeachType!Type;
	mixin Import!SubType;

	static if(isDumbData!SubType)
	{
		alias BinType = Unqual!SubType;
	}
	else
	{
		alias BinType = LNBDescriptor!SubType;
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
		enum Declare = "LNBDescriptor!("~Type.stringof~") "~name~";";
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
		enum FieldAssign = field~" = LNBDescriptor!("~Type.stringof~")(p_base."~field~", p_buffer);";
	}
}

// Struct for loading and storing complex data from a byte buffers without pointers
struct LNBDescriptor(Type)
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

struct LNBHeader
{
	char[4] magic = "LNB_";
	uint bufferSize;
	uint typeSize;
}

T lnbLoad(T)(string p_file, ref Region p_alloc) //@nogc
{
	void readValue(Type)(FILE* p_file, Type* p_ptr, size_t p_count = 1) @nogc
	{
		auto size = fread(cast(void*) p_ptr, Type.sizeof, p_count, p_file);
		assert(size == p_count);
	}

	alias BinType = LNBDescriptor!T;

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

	LNBHeader header;
	readValue!LNBHeader(file, &header);

	assert(header.magic == "LNB_", header.magic);
	assert(header.typeSize == BinType.sizeof, p_file);
	assert(LNBHeader.sizeof + BinType.sizeof + header.bufferSize == fsize, p_file);

	BinType data;
	readValue!BinType(file, &data);

	ubyte[] buffer = p_alloc.makeList!ubyte(header.bufferSize);
	if(buffer.length > 0)
	{
		readValue!ubyte(file, buffer.ptr, buffer.length);
	}
	
	return data.getData(buffer, p_alloc);
}

T lnbLoad(T)(string p_file)
{
	alias BinType = LNBDescriptor!T;

	//pragma(msg, FieldNameTuple!BinType);

	if(!p_file.exists())
	{
		writeln("File does not exist: ", p_file);
		debug assert(false, p_file);
		else return T.init;
	}

	auto file = File(p_file, "rb");

	LNBHeader[] headerBuffer = new LNBHeader[1];
	file.rawRead(headerBuffer);

	LNBHeader header = headerBuffer[0]; 

	assert(header.magic == "LNB_", header.magic);
	assert(header.typeSize == BinType.sizeof, p_file);
	assert(LNBHeader.sizeof + BinType.sizeof + header.bufferSize == file.size, p_file);

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

void lnbStore(T)(string p_file, auto ref T p_data)
{
	alias BinType = LNBDescriptor!T;

	ubyte[] buffer;
	buffer.reserve(ushort.max);
	BinType data = BinType(p_data, buffer);

	LNBHeader header = LNBHeader();
	header.typeSize = BinType.sizeof;
	header.bufferSize = cast(uint)buffer.length;

	auto file = File(p_file, "wb");
	file.rawWrite((&header)[0..1]);
	file.rawWrite((&data)[0..1]);
	
	if(buffer.length > 0)
	{
		file.rawWrite(buffer);
	}

	//debug
	//{
	//	auto text = File(p_file ~".log", "w");
	//	text.writeln(p_file);
	//	text.writeln(header);
	//	text.writeln(data);
	//	text.writeln(buffer);
	//}
}