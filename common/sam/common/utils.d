module sam.common.utils;

import std.traits;
import std.conv;

template nameOf(alias nameType)
{
    enum nameOf = __traits(identifier, nameType);
}

template ctString(alias strings)
{
    enum ctString = strings;
}

string actorPath(TypeInfo actorType, string id)
{
    return to!string(actorType) ~ ":" ~ id;
}

enum bool isValidReferenceTypeActorArgument(T) = (is(T == class) || isArray!T || isAssociativeArray!T) && !__traits(isTemplate, T);
enum bool isValidValueTypeActorArgument(T) = (is(T == struct) || is(T == enum)) && !__traits(isTemplate, T);

version (unittest)
{
    import fluent.asserts;

    private class NameOfTestObject
    {
    }

    private struct NameOfTestStruct
    {
    }

    string returnString()
    {
        return "test";
    }
}

@("nameOf should return name of subject")
unittest
{    
    auto variable = 10;
    nameOf!variable.should.equal("variable");

    nameOf!NameOfTestObject.should.equal("NameOfTestObject");
    nameOf!NameOfTestStruct.should.equal("NameOfTestStruct");
}

@("nameOf should return name of subject")
unittest
{    
    static assert(ctString!(returnString ~ "nice") == "testnice");
}

