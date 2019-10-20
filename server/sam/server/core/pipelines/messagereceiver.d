module sam.server.core.pipelines.messagereceiver;

import std.variant;
import sam.common.enforce;
import sam.common.actormessage;
import sam.common.actorresponse;
import sam.common.interfaces.messagereceiver;
import sam.server.core.actormanagment.actorprovider;

class MessageReceiver : IMessageReceiver
{
	ActorProvider provider;

	this(ActorProvider provider)
	{
		this.provider = provider.notNull;
	}

	ActorResponse receive(ActorMessage message)
	{
		auto mailbox = provider.mailboxOf(message.actorType, message.actorId);
		return mailbox.put(message).getResult;
	}
}
