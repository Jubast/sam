module sam.client.actorref;

import std.stdio;
import std.traits
;
import sam.common.enforce;
import sam.common.exceptions;
import sam.common.actormessage;
import sam.common.actorresponse;
import sam.common.argument;
import sam.common.interfaces.actor;
import sam.common.interfaces.messagesender;

import sam.client.messagesender;
import sam.client.overrideprovider;

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
	private Argument send(Args...)(string method, Args args)
	{
		auto message = new ActorMessage(typeid(TIActor), id, method, args);
		return messageSender.send(message).value;
	}
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

	auto message = new ActorMessage(typeid(ITestActor), "test", id);
	auto response = new ActorResponse(null);

	sender.expect!"send"(message);
	sender.returnValue!"send"(response);

	auto testActor = new ActorRef!ITestActor(id, sender);
	testActor.test();

	sender.verify;
}
