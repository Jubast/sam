module sam.common.argument;

import std.traits;
import sam.common.exceptions;

class Argument
{
    private BaseBox m_boxedValue;

    TypeInfo type()
    {
        return m_boxedValue.type;
    }

    this(T)(T value)
    {
        m_boxedValue = new Box!T(value);
    }

    T get(T)()
    {
        return m_boxedValue.get!T;
    }

    override bool opEquals(Object b)
    {
        auto other = cast(Argument) b;
        return other !is null && m_boxedValue == other.m_boxedValue;
    }

    override size_t toHash()
    {        
        return m_boxedValue.toHash();
    }
}

class Box(T) : BaseBox
{
    T value;

    this(T value)
    {
        this.value = value;
        super(typeid(T));
    }

    override bool opEquals(Object b)
    {
        auto other = cast(Box) b;
        return other !is null && value == other.value && super.opEquals(b);
    }

    override size_t toHash()
    {
        static if(!__traits(compiles, { value.hashOf; }))
        {
            return type.hashOf(typeid(T).hashOf);
        }

        return type.hashOf(value.hashOf);
    }
}

class BaseBox
{
    TypeInfo type;

    this(TypeInfo type)
    {
        this.type = type;
    }

    T get(T)()
    {
        if (type != typeid(T))
        {
            throw new InvalidOperationException(
                    "Invalid cast of '" ~ type.toString ~ "' to '" ~ T.stringof ~ "'");
        }

        auto box = cast(Box!T) this;
        if (box is null)
        {
            static if (__traits(compiles, { T t = null; }))
            {
                return null;
            }
            else
            {
                throw new InvalidOperationException(
                        "Invalid cast of '" ~ type.toString ~ "' to '" ~ T.stringof ~ "'");
            }
        }

        return box.value;
    }

    override bool opEquals(Object b)
    {
        auto other = cast(BaseBox) b;
        return other !is null && type == other.type;
    }

    override size_t toHash()
    {        
        return type.hashOf();
    }
}
