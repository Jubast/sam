module sam.server.core.actormanagment.actormanager;

import std.variant;
import std.datetime;

import sam.common.enforce;
import sam.common.interfaces.actor;
import sam.common.actormessage;
import sam.common.actorresponse;
import sam.common.exceptions;
import sam.server.core.actormanagment.actorinfo;

class ActorManagerState
{
    SysTime lastInteraction;
    ActorState state;

    this(SysTime lastInteraction, ActorState state)
    {
        this.lastInteraction = lastInteraction;
        this.state = state;
    }
}

// Manages an Actor (Activation, Deactivation, MethodInvokes, etc.)
// Each Actor (actor+id) have one Manager
class ActorManager
{
    IActor actor;
    string actorId;
    ActorInfo actorInfo;    
    SysTime lastInteraction;
    ActorState state = ActorState.Deactivated;

    this(IActor actor, string actorId, ActorInfo actorInfo)
    {
        this.actor = actor.notNull;
        this.actorId = actorId.notNull;
        this.actorInfo = actorInfo.notNull;
    }

    // TODO: cleanup. please... :)
    ActorResponse invoke(ActorMessage message)
    {   
        if(message.methodName == ":managerState:")
        {            
            Variant v;
            v = new ActorManagerState(lastInteraction, state);
            return new ActorResponse(v);
        }

        lastInteraction = Clock.currTime(UTC());

        if(state == state.Deactivated)
        {
            actor.onActivate();
        }

        auto method = actorInfo.getMethodFor(message);
        return method.invoke(actor, message.args);        
    }
}

enum ActorState
{
    Activated,
    Deactivated
}

private MethodInfo getMethodFor(ActorInfo actorInfo, ActorMessage actorMessage)
{
    foreach(methodInfo; actorInfo.methodInfos) 
    {
        if(actorMessage.isForMethod(methodInfo))
        {
            return methodInfo;
        }
    }

    throw new InvalidOperationException("Actor doesn't have a method named '" ~ actorMessage.methodName ~"'.");
}

private bool isForMethod(ActorMessage actorMessage, MethodInfo methodInfo)
{
    if(actorMessage.methodName != methodInfo.name)
    {
        return false;
    }

    if(actorMessage.args.length != methodInfo.args.length)
    {
        return false;
    }

    foreach(i, arg; methodInfo.args) 
    {
        if(actorMessage.args[i].type != arg)
        {
            return false;
        }
    }

    return true;
}