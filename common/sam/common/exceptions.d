module sam.common.exceptions;

class ArgumentException : Exception
{
    @nogc @safe pure nothrow this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(message, file, line, next);
    }
}

class InvalidOperationException : Exception
{
    @nogc @safe pure nothrow this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(message, file, line, next);
    }
}