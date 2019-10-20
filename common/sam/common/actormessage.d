module sam.common.actormessage;

import std.variant;
import sam.common.enforce;

class ActorMessage
{
    TypeInfo actorType;
    string actorId;
    string methodName;
    Variant[] args;

    this(TypeInfo actorType, string actorId, string methodName, Variant[] args)
    {
        this.actorType = actorType.notNull;
        this.actorId = actorId.notNull;
        this.methodName = methodName.notNull;
        this.args = args;
    }

    override bool opEquals(Object b)
    {
        auto other = cast(ActorMessage) b;
        return other !is null && this.actorType == other.actorType && this.actorId == other.actorId
            && this.methodName == other.methodName && this.args == other.args;
    }

    override size_t toHash()
    {
        return actorType.hashOf(methodName.hashOf(actorId.hashOf(args.hashOf)));
    }
}

version (unittest)
{
    import std.uuid;
    import fluent.asserts;
    import sam.common.exceptions;
}

@("ctor should not throw")
unittest
{
    (new ActorMessage(typeid(ActorMessage), "test", "test", [])).should.not.throwAnyException;
}

@("ctor missing actorType should throw")
unittest
{
    (new ActorMessage(null, "test", "test", [])).should.throwException!ArgumentException;
}

@("ctor missing actorId should throw")
unittest
{
    (new ActorMessage(typeid(ActorMessage), null, "test", [])).should.throwException!ArgumentException;
}

@("ctor missing methodName should throw")
unittest
{
    (new ActorMessage(typeid(ActorMessage), "test", null, [])).should.throwException!ArgumentException;
}

@("opEquals should work")
unittest
{
    auto type = typeid(ActorMessage);
    auto id = randomUUID.toString;
    auto method = randomUUID.toString;
    Variant[0] args;

    auto actorMessage1 = new ActorMessage(type, id, method, args);
    auto actorMessage2 = new ActorMessage(type, id, method, args);

    actorMessage1.should.equal(actorMessage2);
}

@("toHash should work")
unittest
{
    auto type = typeid(ActorMessage);
    auto id = randomUUID.toString;
    auto method = randomUUID.toString;
    Variant[0] args;

    auto actorMessage1 = new ActorMessage(type, id, method, args);
    auto actorMessage2 = new ActorMessage(type, id, method, args);

    actorMessage1.toHash.should.equal(actorMessage2.toHash);

    auto actorMessage3 = new ActorMessage(type, randomUUID.toString, randomUUID.toString, args);
    actorMessage1.toHash.should.not.equal(actorMessage3.toHash);
}
