module sam.server.core.pipelines.messagereceiver;

import std.variant;

import vibe.core.log;

import sam.common.utils;
import sam.common.enforce;
import sam.common.actormessage;
import sam.common.actorresponse;
import sam.common.interfaces.messagereceiver;

import sam.server.core.exceptions;
import sam.server.core.introspection;
import sam.server.core.actorprovider;

class MessageReceiver : IMessageReceiver
{
	ActorProvider provider;

	this(ActorProvider provider)
	{
		this.provider = provider.notNull;
	}

	// TODO: exceptions should not be handled here...
	ActorResponse receive(ActorMessage message)
	{
		retry:
		auto activation = provider.activationOf(message.actorType, message.actorId);

		try
		{
			return activation.invoke(message);
		}
		catch (ActorDeactivatedException e)
		{
			logInfo("An message was called on Actor '" ~ actorPath(message.actorType,
					message.actorId) ~ "' which is deactivated. Retrying...");
			goto retry;
		}
		catch(Exception e)
		{			
			logError(e.message);
			throw e;
		}
	}
}
