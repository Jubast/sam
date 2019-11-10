module sam.server.core.containers.aa;

import sam.common.exceptions;

class FixedLengthAA(TKey, TValue)
{
    private bool m_isLocked;
    private TValue[TKey] m_aa;

    void opIndexAssign(TValue value, TKey key, string file = __FILE__, size_t line = __LINE__)
    {
        if (!m_isLocked)
        {
            m_aa[key] = value;
        }
        else
        {
            throw new InvalidOperationException(
                    "Cannot add any elements. The collection is locked!", file, line);
        }
    }

    TValue opIndex(TKey key, string file = __FILE__, size_t line = __LINE__)
    {
        auto value = key in m_aa;
        if (value !is null)
        {
            return *value;
        }

        throw new InvalidOperationException(
                "Could not retreve value for key. No such key exists!", file, line);
    }

    int opApply(int delegate(TValue) operations)
    {
        int result = 0;

        foreach(value; m_aa) 
        {
            result = operations(value);
            if (result)
            {
                break;
            }
        }

        return result;
    }

    TValue* opBinary(string op)(TKey key) 
    {
        static if(op == "in"){
            return key in m_aa;
        }
        else static assert(0, "Operator "~op~" not implemented");
    }

    TValue* opBinaryRight(string op)(TKey key) 
    {
        static if(op == "in"){
            return key in m_aa;
        }
        else static assert(0, "Operator "~op~" not implemented");
    }

    size_t length()
    {
        return m_aa.length;
    }

    bool locked()
    {
        return m_isLocked;
    }

    void lock()
    {
        m_isLocked = true;
    }
}

version(unittest)
{
    import fluent.asserts;
}

@("Index get / set should succeed")
unittest
{
    auto aa = new FixedLengthAA!(string, string);
    aa["test"] = "123";

    aa["test"].should.equal("123");
}

@("Index override should succeed")
unittest
{
    auto aa = new FixedLengthAA!(string, string);
    aa["test"] = "123";
    aa["test"] = "1234";

    aa["test"].should.equal("1234");
}

@("Get unknown should throw")
unittest
{
    auto aa = new FixedLengthAA!(string, string);
    aa["test"].should.throwException!InvalidOperationException;
}

@("length should work")
unittest
{
    auto aa = new FixedLengthAA!(string, string);
    aa["test"] = "test";

    aa.length.should.equal(1);

    aa["test2"] = "test";

    aa.length.should.equal(2);
}

@("foreach should work")
unittest
{
    auto aa = new FixedLengthAA!(string, string);
    aa["testA"] = "test1";
    aa["testB"] = "test2";

    auto count = 0;
    auto testAHit = false;
    auto testBHit = false;
    foreach(value; aa) 
    {
        count++;
        if(value == "test1")
        {
            testAHit = true;
        }

        if(value == "test2")
        {
            testBHit = true;
        }
    }

    count.should.equal(2);
}