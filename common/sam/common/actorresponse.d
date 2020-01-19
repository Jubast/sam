module sam.common.actorresponse;

import sam.common.argument;

class ActorResponse
{
    Argument value;

    this(T)(T value)
    {
        this.value = new Argument(value);
    }
}