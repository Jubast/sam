import std.stdio;

import std.uuid;
import std.conv;
import core.time;

import vibe.core.core;
import vibe.core.log : setLogLevel, LogLevel;

import sam.common.interfaces.actor : IActor;

import sam.client.actorsystem : ActorSystemClient, clientOf;

import sam.server.actor : Actor;
import sam.server.actorsystem : ActorSystem;
import sam.server.actorsystembuilder : ActorSystemBuilder, UseInMemoryActorSystem;

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
	setLogLevel(LogLevel.warn);

	auto actorSystem = new ActorSystemBuilder() //
	.register!(IHelloWorldActor, HelloWorldActor)() //
	.UseInMemoryActorSystem() //
	.build();

	actorSystem.start();
	
	auto client = actorSystem.clientOf();

	runTask({		
		while (true)
		{
			sleep(1000.msecs);
			auto actorId = randomUUID.toString;
			auto actor = client.actorOf!IHelloWorldActor(actorId);
			actor.sayHi("example runner");
		}
	});
	
	runEventLoop();
}
