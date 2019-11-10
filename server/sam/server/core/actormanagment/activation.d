module sam.server.core.actormanagment.activation;

import vibe.core.concurrency;

import sam.common.interfaces.actor;
import sam.common.actormessage;
import sam.common.actorresponse;

import sam.server.core.actormanagment.actorinfo;
import sam.server.core.actormanagment.actormailbox;
import sam.server.core.actormanagment.actorinvoker;

class Activation
{
    private ActorMailbox m_mailbox;
    private static InvokerMessage sm_deactivateActor;
    private static InvokerMessage sm_activateActor;
    private static InvokerMessage sm_invokerState;

    static this()
    {
        sm_deactivateActor = new InvokerMessage("deactivate");
        sm_activateActor = new InvokerMessage("activate");
        sm_invokerState = new InvokerMessage("getInvokerState");
    }

    this(IActor actor, string actorId, ActorInfo actorInfo)
    {
        m_mailbox = new ActorMailbox(actor, actorId, actorInfo);
    }

    ActorResponse invoke(ActorMessage message)
    {
        return m_mailbox.put(message).getResult;
    }

    InvokerResponse invokerState()
    {
        return m_mailbox.putInvoker(sm_invokerState).getResult;
    }

    // TODO: add retry for failing activations
    InvokerResponse activate()
    {
        return m_mailbox.putInvoker(sm_activateActor).getResult;
    }

    // TODO: add retry for failing deactivations
    InvokerResponse deactivate()
    {
        return m_mailbox.putInvoker(sm_deactivateActor).getResult;
    }    
}