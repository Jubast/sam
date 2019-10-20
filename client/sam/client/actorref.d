module sam.client.actorref;

import std.stdio;
import std.variant;
import std.traits;
import sam.common.enforce;
import sam.common.exceptions;
import sam.common.actormessage;
import sam.common.actorresponse;
import sam.client.messagesender;
import sam.client.overrideprovider;
import sam.common.interfaces.actor;
import sam.common.interfaces.messagesender;

class ActorRef(TIActor : IActor)
		if (is(TIActor == interface) && !__traits(isTemplate, TIActor))
{
	string id;
	IMessageSender messageSender;

	this(string id, IMessageSender messageSender)
	{
		this.id = id.notNull;
		this.messageSender = messageSender.notNull;
	}

	// Creates TIActor-s methods
	mixin(OverridesProvider!TIActor);

	// Called by overriden methods of TIActor interface
	private Variant send(Args...)(string method, Args args)
	{
		auto message = new ActorMessage(typeid(TIActor), id, method, toVariants(args));
		return messageSender.send(message).variant;
	}
}

private Variant[] toVariants(Args...)(Args args)
{
	auto variants = new Variant[Args.length];	
	foreach(i, TArg; Args) 
	{
		variants[i] = args[i];
	}	

	return variants;
}

version (unittest)
{
	import unit_threaded.mock;
	import fluent.asserts;
	import std.uuid;

	interface ITestActor : IActor
	{
		void test();
	}
}

@("toVariants should return empty")
unittest
{	
	auto variants = toVariants();
	variants.length.should.equal(0);
}

@("toVariants should return all parameters")
unittest
{
	auto obj = new Object;
	auto variants = toVariants("test", 2, obj, new int[2]);
	variants[0].get!(string).should.equal("test");
	variants[1].get!(int).should.equal(2);
	variants[2].get!(Object).should.equal(obj);
	variants[3].get!(int[]).should.equal(new int[2]);
}

@("ctor should init members")
unittest
{
	auto messageSender = mock!IMessageSender;

	auto id = randomUUID.toString;
	auto testActor = new ActorRef!ITestActor(id, messageSender);

	testActor.id.should.equal(id);
	testActor.messageSender.should.equal(messageSender);
}

@("should create overrides for virtualmethods")
unittest
{
	auto id = randomUUID.toString;
	auto sender = mock!IMessageSender;

	auto message = new ActorMessage(typeid(ITestActor), "test", id, toVariants());
	Variant v;
	auto response = new ActorResponse(v);

	sender.expect!"send"(message);
	sender.returnValue!"send"(response);

	auto testActor = new ActorRef!ITestActor(id, sender);
	testActor.test();

	sender.verify;
}
