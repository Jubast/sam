module sam.server.core.exceptions;

class ActorException : Exception
{
    @safe this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(message, file, line, next);
    }
}

class DuplicateActorException : ActorException
{
    @safe this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(message, file, line, next);
    }
}

class UnknownActorMessageException : ActorException
{
    @safe this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(message, file, line, next);
    }
}

class InvalidActorMessageException : ActorException
{
    @safe this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(message, file, line, next);
    }
}