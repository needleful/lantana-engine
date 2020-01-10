// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module ui.layout;

import lanlib.types;
import ui.render;

// The basic system is inspired by Flutter
// Flutter data layout:
// Construct a tree.
//		From root to leaves, apply constraints
//		from leaves to root, calculate sizes
// Cartesian coordinates (width/height)
//		Intrinsic sizes (max/min dimensions)
//		Intrinsics (min and max) determined by the parent
//		Paradigms: Fixed size; Width-In, Height-Out; Height-in, Width-Out; 
//		Child knows size, parent knows position
//		This means the child's size cannot depend on its position

/// Base UI class.  All UI elements are Widgets
public abstract class Widget
{
	/// Pixel position of the widget, from the bottom left of the screen to the bottom left of the widget
	/// As a rule, the position should ONLY be read by the parent
	public ivec2 position;

	/// First phase of layout, taking some IntrinsicSize (bounds), and providing the real size of the object
	/// Parents calculate the position of their children
	public abstract RealSize layout(UIRenderer p_renderer, IntrinsicSize p_intrinsic) nothrow;

	/// Second phase of layout: this is 
	public void prepareRender(UIRenderer p_renderer, ivec2 p_pen) nothrow
	{
		foreach(child; getChildren())
		{
			child.prepareRender(p_renderer, child.position + p_pen);
		}
	}

	public abstract Widget[] getChildren() nothrow;
}

/// Bounds for laying out UI elements
public struct IntrinsicSize
{
	Bounds width;
	Bounds height;

	public this(Bounds p_width, Bounds p_height) @nogc nothrow
	{
		width = p_width;
		height = p_height;
	}

	const public bool inBounds(int p_width, int p_height) @nogc nothrow
	{
		return width.contains(p_width) && height.contains(p_height);
	}
}

public struct Bounds
{
	double min;
	double max;

	this(double p_min, double p_max = -double.infinity) @nogc nothrow
	{
		if(p_max < p_min)
		{
			p_max = p_min;
		}
		min = p_min;
		max = p_max;
	}

	this(Bounds p_copy) @nogc nothrow
	{
		min = p_copy.min;
		max = p_copy.max;
	}

	const public bool contains(double value) @nogc nothrow
	{
		return min <= value && max >= value;
	}
}

/// The actual size, in pixels, of a UI element
public struct RealSize
{
	int width;
	int height;

	public this(int p_size)
	{
		width = p_size;
		height = p_size;
	}
	
	public this(int p_width, int p_height) @nogc nothrow
	{
		width = p_width;
		height = p_height;
	}

	public this(ivec2 p_vector) @nogc nothrow
	{
		width = p_vector.x;
		height = p_vector.y;
	}

	public RealSize opBinary(string op)(RealSize rhs) @nogc nothrow
	{
		static if(op == "+")
			return RealSize(width + rhs.width, height + rhs.height);
		static if(op == "-")
			return RealSize(width - rhs.width, height - rhs.height);
		else
			assert(false, "No operator '"~op~"' between RealSize objects");
	}

	bool opEquals(RealSize rhs) @nogc nothrow const
	{
		return width == rhs.width && height == rhs.height;
	}

	bool contains(RealSize rhs) @nogc nothrow const
	{
		return width >= rhs.width && height >= rhs.height;
	}
}