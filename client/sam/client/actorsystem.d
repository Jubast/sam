module sam.client.actorsystem;

import poodinis;
import sam.client.actorref;
import sam.common.enforce;
import sam.common.interfaces.actor;
import sam.common.interfaces.messagesender;

class ActorSystemClient
{
    private IMessageSender messageSender;

    this(IMessageSender messageSender)
    {
        this.messageSender = messageSender.notNull;
    }

    ActorRef!TIActor actorOf(TIActor : IActor)(string id)
    {
        return new ActorRef!TIActor(id, messageSender);
    }
}
