module sam.server.actor;

import sam.common.enforce;
import sam.common.interfaces.actor;
import sam.common.udas;

abstract class Actor : IActor
{
    @ActorId string id;

    override void onActivate()
    {        
    }

    override void onDeactivate()
    {        
    }
}

version(unittest)
{
    import fluent.asserts;
    import sam.common.exceptions;
    import std.uuid;

    private class TestActor : Actor
    {
    }
}

@("Actor onActivate succeeds")
unittest
{
    auto actor = new TestActor();
    (actor.onActivate()).should.not.throwException!ArgumentException;
}

@("Actor onDeactivate succeeds")
unittest
{
    auto actor = new TestActor();
    (actor.onDeactivate()).should.not.throwException!ArgumentException;
}
