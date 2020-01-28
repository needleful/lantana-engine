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

private enum isSimpleType(Type) = isBasicType!Type || isStaticArray!Type;
private enum isSimpleStruct(Type) = isSimpleType!Type || allSatisfy!(isSimpleType, Fields!Type);
private enum isDumbData(Type) = isSimpleStruct!Type || allSatisfy!(isSimpleStruct, Fields!Type);

private template StripType(T)
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

private mixin template Import(Type)
{
	//pragma(msg, "\tTrying to import ", Type);
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
		//pragma(msg, "\timport "~pkg~": "~toImport.stringof.split("(")[0]~";");
	}
}

private struct LNBDescriptor(Type)
	if(isDumbData!Type)
{
	static foreach(subType; Fields!Type)
	{
		mixin Import!subType;
	}
	alias valType = Type;
	alias BinType = Unqual!Type;
	BinType base;

	this(Type p_base, ref ubyte[] p_buffer)
	{
		base = cast(BinType) p_base;
		debug writefln("D\t", Type.stringof, " <= ", p_base);
	}

	Type getData(ref ubyte[] p_buffer)
	{
		debug writeln(Type.stringof, " ", base);
		return cast(Type) base;
	}

	Type getData(ref ubyte[] p_buffer, ref Region _)
	{
		return cast(Type) base;
	}

}

private struct LNBDescriptor(Type)
	if(isPointer!Type)
{
	alias valType = Type;
	alias SubType = PointerTarget!Type;
	alias BinType = LNBDescriptor!(SubType);
	mixin Import!SubType;

	ulong byteOffset;
	this(Type p_base, ref ubyte[] p_buffer)
	{
		byteOffset = p_buffer.length;
		p_buffer.length += BinType.sizeof;

		static if(isDumbData!SubType)
		{
			auto ptr = cast(SubType*)(&p_buffer[byteOffset]);
			emplace!SubType(ptr, *p_base);
		}
		else
		{
			auto ptr = cast(BinType*) &p_buffer[byteOffset];
			emplace!BinType(ptr, *p_base, p_buffer);
		}
		//writefln("Store %s: [%u..%u]", Type.stringof, byteOffset, byteOffset + Type.sizeof);
	}

	Type getData(ref ubyte[] p_buffer)
	{
		static if(isDumbData!SubType)
		{
			auto ptr = cast(Type)(&p_buffer[byteOffset]);
			//writeln(Type.stringof, ": ", ptr);
			return ptr;
		}
		else
		{
			BinType* data = cast(BinType*)&p_buffer[byteOffset];
			write(Type.stringof, ": \n\t");
			return &data.getData();
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
			return cast(Type) p_alloc.make!SubType(data.getData());
		}
	}
}

private struct LNBDescriptor(Type)
	if(isDynamicArray!Type)
{
	alias valType = Type;
	alias SubType = ForeachType!Type;
	mixin Import!SubType;

	//pragma(msg, "\nSerializing ", Type, ":");
	static if(isDumbData!SubType)
	{
		//pragma(msg, "\tDumb data type: ", SubType);
		alias BinType = Unqual!SubType;
	}
	else
	{
		//pragma(msg, "\tComplex data type: ", SubType);
		alias BinType = LNBDescriptor!SubType;
	}
	static if(isArray!SubType)
	{
		//pragma(msg, "\tNested array: ", Type);
	}
	uint count;
	uint byteOffset;

	this(Type p_array, ref ubyte[] p_buffer)
	{
		//writeln("Dynamic array: ", Type.stringof);
		count = cast(uint)p_array.length;
		byteOffset = cast(uint)p_buffer.length;

		debug writefln("Store %s: [%u..%u]", Type.stringof, byteOffset, byteOffset + SubType.sizeof*count);
		if(p_array.length == 0)
		{
			debug writeln(Type.stringof,"~~empty");
			return;
		}

		p_buffer.length += count*BinType.sizeof;
		static if(isDumbData!SubType)
		{
			auto data = cast(BinType*)(&p_buffer[byteOffset]);
			data[0..count] = p_array[0..count];

			debug writefln("--\t %u elements [%u bytes per elem]", count, SubType.sizeof);
		}
		else foreach(i; 0..count)
		{
			debug writeln("--\t", p_array[i]);

			auto byteStart = byteOffset+i*BinType.sizeof;
			auto byteEnd = byteStart + BinType.sizeof;

			foreach(attempt; 0..4)
			{
				debug writeln("\t = ", p_buffer[byteStart..byteEnd]);
				(cast(BinType*)&p_buffer[byteStart]).emplace!BinType(p_array[i], p_buffer);
			}

			debug writeln("\t = ", *(cast(BinType*)&p_buffer[byteStart]));
		}
	}

	Type getData(ref ubyte[] p_buffer)
	{
		//writefln("\nLoad %s: [%u..%u]", Type.stringof, byteOffset, byteOffset + Type.sizeof*count);
		//debug writeln(Type.stringof);
		if(count == 0)
		{
			//writeln("\t empty.");
			return cast(Type) [];
		}
		BinType[] binArray = (cast(BinType*)&p_buffer[byteOffset])[0..count];

		static if(isDumbData!SubType)
		{
			//writeln("\t", count, " elements");
			return cast(Type) binArray;
		}
		else 
		{
			SubType[] array = new SubType[count];
			foreach(i, ref bin; binArray)
			{
				array[i] = binArray[i].getData(p_buffer);
				debug 
				{
					writeln("\t ", binArray[i]);
					writeln("\t=", array[i]);
				}
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
		BinType[] binArray = (cast(BinType*)&p_buffer[byteOffset])[0..count];

		static if(isDumbData!SubType)
		{
			return cast(Type) binArray;
		}
		else
		{
			SubType[] array = p_alloc.makeList!SubType(count);
			foreach(i, ref bin; binArray)
			{
				array[i] = binArray[i].getData(p_buffer);
				//debug writeln("\t", array[i], " = ", binArray[i]);
			}
			return cast(Type) array;
		}
	}
	//pragma(msg, "--- End ", Type);
}

private template Declare(Type, string name)
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

private template BaseAssign(Type, string base, string field)
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

private template BaseAssignAlloc(Type, string base, string field)
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

private template FieldAssign(Type, string field)
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
private struct LNBDescriptor(Type)
	if(is(Type == struct) && !isDumbData!Type)
{
	alias valType = Type;
	//pragma(msg, "\nSerializing ", Type, ":");
	enum fieldNames = FieldNameTuple!Type;

	static foreach(i, type; Fields!Type)
	{
		mixin Import!type;
		mixin(Declare!(type, fieldNames[i].stringof[1..$-1]));
		//pragma(msg, "->>", Declare!(type, fieldNames[i].stringof[1..$-1]));
	}

	this(Type p_base, ref ubyte[] p_buffer)
	{
		debug writeln(Type.stringof);
		static foreach(i, type; Fields!Type)
		{
			mixin(FieldAssign!(type, fieldNames[i].stringof[1..$-1]));
			//writeln(" ::\t", fieldNames[i], " = ", mixin(fieldNames[i]));
			//pragma(msg, "\t", FieldAssign!(type, fieldNames[i].stringof[1..$-1]));
		}
	}

	Type getData(ref ubyte[] p_buffer)
	{
		Type val;
		static foreach(i, type; Fields!Type)
		{
			//pragma(msg, "\t", BaseAssign!(type, val.stringof, fieldNames[i].stringof[1..$-1]));
			//writeln("\t", fieldNames[i].stringof[1..$-1], " = ", mixin(fieldNames[i]));
			mixin(BaseAssign!(type, val.stringof, fieldNames[i].stringof[1..$-1]));
		}
		return val;
	}

	Type getData(ref ubyte[] p_buffer, ref Region p_alloc)
	{
		Type val;
		static foreach(i, type; Fields!Type)
		{
			//pragma(msg, "\t", BaseAssignAlloc!(type, val.stringof, fieldNames[i].stringof[1..$-1]));
			mixin(BaseAssignAlloc!(type, val.stringof, fieldNames[i].stringof[1..$-1]));
		}
		return val;
	}
	//pragma(msg, "--- End ", Type);
}

struct LNBHeader
{
	char[4] magic = "LNB_";
	uint bufferSize;
	uint typeSize;
}

T lnbLoad(T)(string p_file, ref Region p_alloc) @nogc
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
	scope(exit) fclose(file);
	int fsize;
	fseek(file, 0, SEEK_END);
	fsize = ftell(file);
	rewind(file);

	LNBHeader header;
	readValue!LNBHeader(file, &header);

	assert(header.magic == "LNB_", header.magic);
	assert(header.typeSize == BinType.sizeof);
	assert(LNBHeader.sizeof + BinType.sizeof + header.bufferSize == fsize);

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

	auto file = File(p_file, "rb");

	LNBHeader[] headerBuffer = new LNBHeader[1];
	file.rawRead(headerBuffer);

	LNBHeader header = headerBuffer[0]; 

	assert(header.magic == "LNB_", header.magic);
	assert(header.typeSize == BinType.sizeof);
	assert(LNBHeader.sizeof + BinType.sizeof + header.bufferSize == file.size);

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
	//	auto val = data.getData(buffer);
	//	assert(p_data == val);
	//}
}