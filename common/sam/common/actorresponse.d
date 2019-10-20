module sam.common.actorresponse;

import std.variant;

class ActorResponse
{
    Variant variant;

    this(Variant variant)
    {
        this.variant = variant;
    }
}