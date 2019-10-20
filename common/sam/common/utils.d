module sam.common.utils;

template nameOf(alias nameType)
{
    enum nameOf = __traits(identifier, nameType);
}

template ctString(alias strings)
{
    enum ctString = strings;
}

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

