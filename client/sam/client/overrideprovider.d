module sam.client.overrideprovider;

import std.conv;
import std.traits;
import sam.common.interfaces.actor;

template OverridesProvider(TIActor : IActor)
		if (is(TIActor == interface) && !__traits(isTemplate, TIActor))
{
	enum OverridesProvider = generateMethods!TIActor;
}

string generateMethods(TIActor)()
{
	string methods;

	static foreach (member; __traits(allMembers, TIActor))
	{
		static foreach (index, overload; __traits(getOverloads, TIActor, member))
		{
			static if (__traits(isVirtualMethod, overload))
			{
				methods ~= generateOverride!(member, index, overload);
			}
		}
	}

	return methods;
}

string generateOverride(string methodName, ulong index, alias overload)()
{
	enum method = `__traits(getOverloads, TIActor, "` ~ methodName ~ `")[` ~ index.to!string ~ `]`;
	enum methodReturnType = "ReturnType!(" ~ method ~ ")";
	enum methodParamters = "Parameters!(" ~ method ~ ")";

	enum methodHeader = "final " ~ methodReturnType ~ " " ~ methodName ~ "("
		~ methodParamters ~ " args)";

	enum methodBody = `
    {
        static if(is(` ~ methodReturnType ~ ` == void))
        {
            send("` ~ methodName ~ `", args);
        }
        else
        {
			auto response = send("` ~ methodName ~ `", args);
			if (response.convertsTo!(` ~ methodReturnType ~ `))
			{
				return response.get!(` ~ methodReturnType ~ `);
			}

			static if(__traits(compiles, {` ~ methodReturnType ~ ` rt = null; }))
			{
				if (response.type == typeid(null))
				{
					return cast(`~ methodReturnType ~`)null;
				}
			}

			throw new InvalidOperationException(
				"For Method '` ~ methodName ~ `' response '" ~ response.type.toString
				~ "' is not convertabile to '" ~ typeid(` ~ methodReturnType ~ `).toString ~ "'");
        }
    }
    `;

	return methodHeader ~ methodBody;
}

version (unittest)
{
	import std.variant;
	import sam.common.exceptions;
	import fluent.asserts;

	interface ITestInterface : IActor
	{
		// should create overloads for:
		void set(int i);
		int get();
		int get(int i);
		void save();

		void simpleCall(string text, int age, bool valid);
		string simpleQuery(string text, int age, bool valid);
		string unknownReturnType();

		void complexCall(string text, TestMessage message);
		TestMessage complexQuery(string text, TestMessage message);		

		// should not create overloads for:
		final void noFinal()
		{
			throw new InvalidOperationException("Not implemented");
		}

		static void noStatic()
		{
			throw new InvalidOperationException("Not implemented");
		}
	}

	class TestMessage
	{
		string name;
		int age;
		bool valid;

		this(string name, int age, bool valid)
		{
			this.name = name;
			this.age = age;
			this.valid = valid;
		}

		override string toString() const
		{
			return TestMessage.stringof ~ name ~ to!string(age) ~ to!string(valid);
		}
	}

	class TestGenerateClass(TIActor) : TIActor
	{
		string[string] lastInvoke;

		mixin(OverridesProvider!TIActor);

		Variant send(Args...)(string methodName, Args args)
		{
			string[string] thisInvoke;
			thisInvoke["MethodName"] = methodName;

			foreach (index, arg; args)
			{
				thisInvoke[("Param-" ~ to!string(index))] = to!string(arg);
			}

			lastInvoke = thisInvoke;

			Variant variant;
			if(methodName == "get")
			{
				variant = 1;
			}
			else if(methodName == "simpleQuery")
			{
				variant = "";
			}
			else if(methodName == "unknownReturnType")
			{
				variant = cast(TestGenerateClass)null;
			}
			else
			{
				variant = null;
			}
			
			return variant;
		}
	}
}

@("should generate code")
unittest
{
	string code = OverridesProvider!ITestInterface;
	code.should.not.equal(null);
}

@("Mixin should succeed")
unittest
{
	auto testClass = new TestGenerateClass!ITestInterface;
	testClass.set(10);
	testClass.lastInvoke.length.should.equal(2);
	testClass.lastInvoke["MethodName"].should.equal("set");
	testClass.lastInvoke["Param-0"].should.equal(to!string(10));

	testClass.get();
	testClass.lastInvoke.length.should.equal(1);
	testClass.lastInvoke["MethodName"].should.equal("get");

	testClass.get(10);
	testClass.lastInvoke.length.should.equal(2);
	testClass.lastInvoke["MethodName"].should.equal("get");
	testClass.lastInvoke["Param-0"].should.equal(to!string(10));

	testClass.save();
	testClass.lastInvoke.length.should.equal(1);
	testClass.lastInvoke["MethodName"].should.equal("save");

	testClass.simpleCall("message", 10, true);
	testClass.lastInvoke.length.should.equal(4);
	testClass.lastInvoke["MethodName"].should.equal("simpleCall");
	testClass.lastInvoke["Param-0"].should.equal("message");
	testClass.lastInvoke["Param-1"].should.equal(to!string(10));
	testClass.lastInvoke["Param-2"].should.equal(to!string(true));

	testClass.simpleQuery("message", 10, true);
	testClass.lastInvoke.length.should.equal(4);
	testClass.lastInvoke["MethodName"].should.equal("simpleQuery");
	testClass.lastInvoke["Param-0"].should.equal("message");
	testClass.lastInvoke["Param-1"].should.equal(to!string(10));
	testClass.lastInvoke["Param-2"].should.equal(to!string(true));

	(testClass.unknownReturnType).should.throwException!InvalidOperationException;
	testClass.lastInvoke["MethodName"].should.equal("unknownReturnType");

	testClass.complexCall("message", new TestMessage("test", 10, true));
	testClass.lastInvoke.length.should.equal(3);
	testClass.lastInvoke["MethodName"].should.equal("complexCall");
	testClass.lastInvoke["Param-0"].should.equal("message");
	testClass.lastInvoke["Param-1"].should.equal("TestMessagetest10true");

	testClass.complexQuery("message", new TestMessage("test", 10, true));
	testClass.lastInvoke.length.should.equal(3);
	testClass.lastInvoke["MethodName"].should.equal("complexQuery");
	testClass.lastInvoke["Param-0"].should.equal("message");
	testClass.lastInvoke["Param-1"].should.equal("TestMessagetest10true");
}

@("Should not create overloads for static and final methods")
unittest
{
	auto testClass = new TestGenerateClass!ITestInterface;
	testClass.noFinal.should.throwException!InvalidOperationException.msg.should.equal(
			"Not implemented");
	testClass.noStatic.should.throwException!InvalidOperationException.msg.should.equal(
			"Not implemented");
}
