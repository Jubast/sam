module sam.server.core.actormanagment.actormanager;

import std.variant;
import std.datetime;

import sam.common.enforce;
import sam.common.interfaces.actor;
import sam.common.actormessage;
import sam.common.actorresponse;
import sam.common.exceptions;
import sam.server.core.actormanagment.actorinfo;

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
    
    ActorResponse invoke(ActorMessage message)
    {
        lastInteraction = Clock.currTime(UTC());

        if(state == ActorState.Deactivated)
        {
            actor.onActivate();
            state = ActorState.Activated;
        }

        auto method = actorInfo.getMethodFor(message);
        return method.invoke(actor, message.args);        
    }

    package ManagerResponse managerMessage(ManagerMessage message)
    {
        Variant v;
        if(message.messageType == "getManagerState")
        {            
            v = new ActorManagerStatus(actorInfo.actorType, actorId, lastInteraction, state);            
        }
        if(message.messageType == "deactivate")
        {
            actor.onDeactivate;
        }

        return new ManagerResponse(v);
    }
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

enum ActorState
{
    Activated,
    Deactivated
}

class ActorManagerStatus
{
    TypeInfo actorType;
    string actorId;
    SysTime lastInteraction;
    ActorState state;

    this(TypeInfo actorType, string actorId, SysTime lastInteraction, ActorState state)
    {
        this.actorType = actorType;
        this.actorId = actorId;
        this.lastInteraction = lastInteraction;
        this.state = state;
    }
}

class ManagerResponse
{
    Variant variant;

    this(Variant variant)
    {
        this.variant = variant;
    }
}

class ManagerMessage
{
    string messageType;

    this(string messageType)
    {
        this.messageType = messageType;
    }
}