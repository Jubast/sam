module sam.common.interfaces.messagesender;

import sam.common.actormessage;
import sam.common.actorresponse;

interface IMessageSender
{	
	ActorResponse send(ActorMessage message);
}
