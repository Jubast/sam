module sam.server.core.lifetime.activation;

import std.datetime;
import std.datetime.systime;

import vibe.core.concurrency;

import sam.common.interfaces.actor;
import sam.common.actormessage;
import sam.common.actorresponse;

import sam.server.core.scheduler;
import sam.server.core.introspection;

class Activation
{
    private static ManagerMessage sm_deactivateActor;
    private static ManagerMessage sm_activateActor;

    static this()
    {
        sm_deactivateActor = new ManagerMessage("deactivate");
        sm_activateActor = new ManagerMessage("activate");
    }

    private ActorTaskScheduler m_actorTaskScheduler;
    private SysTime m_lastInteraction;

    ActivationStatus status()
    {
        return new ActivationStatus(m_actorTaskScheduler.actorId, m_actorTaskScheduler.actorType, m_lastInteraction);
    }

    this(IActor actor, string actorId, ActorInfo actorInfo)
    {
        m_actorTaskScheduler = new ActorTaskScheduler(actor, actorId, actorInfo);
    }

    ActorResponse invoke(ActorMessage message)
    {
        m_lastInteraction = Clock.currTime(UTC());

        return m_actorTaskScheduler.put(message).getResult;
    }

    ManagerResponse activate()
    {
        m_lastInteraction = Clock.currTime(UTC());

        return m_actorTaskScheduler.managerPut(sm_activateActor).getResult;
    }

    ManagerResponse deactivate()
    {
        m_lastInteraction = Clock.currTime(UTC());

        return m_actorTaskScheduler.managerPut(sm_deactivateActor).getResult;
    }
}

class ActivationStatus
{
    string actorId;
    TypeInfo actorType;
    SysTime lastInteraction;

    this(string actorId, TypeInfo actorType, SysTime lastInteraction)
    {
        this.actorId = actorId;
        this.actorType = actorType;
        this.lastInteraction = lastInteraction;
    }
}
