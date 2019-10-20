module sam.common.enforce;

import std.uni;
import sam.common.exceptions;
import sam.common.utils;

pragma(inline, true) 
@safe pure T notNull(T)(T a, string message = null,
        string file = __FILE__, size_t line = __LINE__)
        if (__traits(compiles, { T t = null; }))
{
    if (a is null)
    {
        if (message is null)
        {
            message = ctString!(typeof(a).stringof ~ " must not be null");
        }

        throw new ArgumentException(message, file, line);
    }

    return a;
}

pragma(inline, true) 
@safe pure string notEmpty(string s, string message = null,
        string file = __FILE__, size_t line = __LINE__)
{
    if(s !is null && s.length == 0)
    {
        if (message is null)
        {
            message = ctString!(typeid(string).stringof ~ " must not be empty");
        }

        throw new ArgumentException(message, file, line);
    }

    return s;
}

pragma(inline, true) 
@safe pure string notWhite(string s, string message = null,
        string file = __FILE__, size_t line = __LINE__)
{
    if(s !is null && s.isWhiteS)
    {
        if (message is null)
        {
            message = ctString!(typeid(string).stringof ~ " must not be white space");
        }

        throw new ArgumentException(message, file, line);
    }

    return s;
}

pragma(inline, true)
@safe pure nothrow @nogc private bool isWhiteS(string s)
{
    for(auto i = 0; i < s.length; ++i)
    {
        if(s[i].isWhite)
        {
            return true;
        }
    }

    return false;
}

version (unittest)
{
    import fluent.asserts;
}

@("notNull subject is null should throw")
unittest
{
    Object o = null;

    (o.notNull).should.throwException!ArgumentException.msg.should.equal(
            "Object must not be null");
}

@("notNull subject is null with message should throw with message")
unittest
{
    Object o = null;

    (o.notNull("Hello World!, aggregate was null")).should
        .throwException!ArgumentException.msg.should.equal("Hello World!, aggregate was null");
}

@("notNull subject not null should not throw")
unittest
{
    Object o = new Object;
    (o.notNull()).should.not.throwAnyException;
}

@("notEmpty subject empty should throw")
unittest
{    
    ("".notEmpty).should.throwException!ArgumentException;
}

@("notEmpty subject not empty should not throw")
unittest
{    
    (" ".notEmpty).should.not.throwAnyException;
}

@("notEmpty subject null should not throw")
unittest
{    
    (null.notEmpty).should.not.throwAnyException;
}

@("notWhite subject empty should not throw")
unittest
{    
    ("".notWhite).should.not.throwAnyException;
}

@("notWhite subject space should throw")
unittest
{    
    (" ".notWhite).should.throwException!ArgumentException;
}

@("notWhite subject tab should throw")
unittest
{    
    ("\t".notWhite).should.throwException!ArgumentException;
}

@("notWhite subject multiple whitespaces should throw")
unittest
{    
    (" \t ".notWhite).should.throwException!ArgumentException;
}

@("notWhite subject null should not throw")
unittest
{    
    (null.notWhite).should.not.throwAnyException;
}