import std.stdio;

import std.uuid;
import std.conv;
import core.time;
import vibe.core.core;

import sam.server.actor : Actor;
import sam.server.actorsystem : ActorSystem, ActorSystemBuilder, UseInMemoryActorSystem;
import sam.common.interfaces.actor : IActor;

interface IHelloWorldActor : IActor
{
	void sayHi(string name);
}

class HelloWorldActor : Actor, IHelloWorldActor
{
	void sayHi(string name)
	{
		writeln("Hi " ~ name ~ ", from actor '" ~ id ~ "'");
	}
}

void main()
{
	auto actorSystem = new ActorSystemBuilder() //
	.register!(IHelloWorldActor, HelloWorldActor) //
	.UseInMemoryActorSystem //
	.build;

	auto client = actorSystem.clientOf;

	runTask({
		while(true)
		{
			sleep(500.msecs);
			auto actorId = randomUUID.toString;
			auto actor = client.actorOf!IHelloWorldActor(actorId);
			actor.sayHi("example runner");
		}
	});	

	runApplication;
}
