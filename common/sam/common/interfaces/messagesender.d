module sam.common.interfaces.messagesender;

import std.variant;
import sam.common.actormessage;
import sam.common.actorresponse;

interface IMessageSender
{	
	ActorResponse send(ActorMessage message);
}
