module sam.client.actorsystem;

import sam.client.actorref;

import sam.common.enforce;
import sam.common.interfaces.actor;
import sam.common.interfaces.messagesender;
import sam.common.interfaces.actorsystem;

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

ActorSystemClient clientOf(IActorSystem actorSystem)
{
    return new ActorSystemClient(actorSystem.container.resolve!IMessageSender);
}