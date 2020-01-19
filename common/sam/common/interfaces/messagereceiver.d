module sam.common.interfaces.messagereceiver;

import sam.common.actormessage;
import sam.common.actorresponse;

interface IMessageReceiver
{
	ActorResponse receive(ActorMessage message);	
}
