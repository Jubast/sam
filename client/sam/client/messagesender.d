module sam.client.messagesender;

import std.variant;
import sam.common.enforce;
import sam.common.actormessage;
import sam.common.actorresponse;
import sam.common.interfaces.messagesender;
import sam.common.interfaces.messagereceiver;

class MessageSender : IMessageSender		
{
	IMessageReceiver messageReceiver;

	this(IMessageReceiver messageReceiver)
	{
		this.messageReceiver = messageReceiver.notNull;
	}

	ActorResponse send(ActorMessage message)
	{
		return messageReceiver.receive(message);
	}
}