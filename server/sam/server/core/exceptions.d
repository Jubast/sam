module sam.server.core.exceptions;

class ActorInvokerException : Exception
{
    @safe this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(message, file, line, next);
    }
}

class ActorNotActivatedException : ActorInvokerException
{
    @safe this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(message, file, line, next);
    }
}

class ActorDeactivatedException : ActorInvokerException
{
    @safe this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(message, file, line, next);
    }
}

class InvalidActorMessageException : ActorInvokerException
{
    @safe this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(message, file, line, next);
    }
}

class InvalidActorTypeException : ActorInvokerException
{
    @safe this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(message, file, line, next);
    }
}