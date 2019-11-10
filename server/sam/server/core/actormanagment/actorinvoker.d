module sam.server.core.actormanagment.actorinvoker;

import std.conv;
import std.variant;
import std.datetime;

import vibe.core.log;

import sam.common.utils;
import sam.common.enforce;
import sam.common.interfaces.actor;
import sam.common.actormessage;
import sam.common.actorresponse;
import sam.common.exceptions;

import sam.server.core.actormanagment.actorinfo;
import sam.server.core.exceptions;

class ActorInvoker
{
    IActor actor;
    string actorId;
    ActorInfo actorInfo;
    SysTime lastInteraction;
    ActorState actorState;

    this(IActor actor, string actorId, ActorInfo actorInfo)
    {
        this.actor = actor.notNull;
        this.actorId = actorId.notNull;
        this.actorInfo = actorInfo.notNull;

        this.actorState = ActorState.Created;
    }

    ActorResponse invoke(ActorMessage message)
    {
        lastInteraction = Clock.currTime(UTC());

        throwIfInvalidState();
        auto method = actorInfo.getMethodFor(message);
        return method.invoke(actor, message.args);
    }

    package InvokerResponse invokeInvoker(InvokerMessage message)
    {
        Variant v;
        if (message.messageType == "getInvokerState")
        {
            v = new ActorInvokerStatus(actorInfo.actorType, actorId, lastInteraction, actorState);
        }
        if (message.messageType == "deactivate")
        {
            deactivate();
        }
        if (message.messageType == "activate")
        {
            activate();
        }

        return new InvokerResponse(v);
    }

    private void throwIfInvalidState()
    {
        if (actorState == ActorState.Active)
            return;        

        if (actorState == ActorState.Deactivated)
        {
            // this exception should get caught, and a new actor should be created.
            throw new ActorDeactivatedException("Actor '" ~ actorPath(actorInfo.actorType,
                    actorId) ~ "' is deactivated. So it can't process messages.");
        }

        if (actorState == ActorState.ActivateFailed)
        {
            // bug
            throw new ActorNotActivatedException("Actor '" ~ actorPath(actorInfo.actorType, actorId)
                    ~ "' failed to activate. So it can't process messages. This exception should never happen.");
        }

        if (actorState == ActorState.DeactivateFailed)
        {
            // bug
            throw new ActorInvokerException("Actor '" ~ actorPath(actorInfo.actorType, actorId)
                    ~ "' failed to deactivate. So it can't process messages. This exception should never happen.");
        }

        if (actorState == ActorState.Created)
        {
            // bug
            throw new ActorNotActivatedException("Actor '" ~ actorPath(actorInfo.actorType, actorId)
                    ~ "' is not activated yet. So it can't process messages. This exception should never happen.");
        }

        if (actorState == ActorState.Activating)
        {
            // bug
            throw new ActorNotActivatedException("Actor '" ~ actorPath(actorInfo.actorType, actorId)
                    ~ "' is beeing activated. So it can't process messages. This exception should never happen.");
        }        
    }

    private void activate()
    {
        if (actorState == ActorState.Created)
        {
            actorState = ActorState.Activating;
            
            try
            {
                logInfo("Activating actor '" ~ actorPath(actorInfo.actorType, actorId) ~ "'...");
                actor.onActivate();
            }
            catch(Exception e)
            {
                actorState = ActorState.ActivateFailed;
                throw e;
            }
            
            actorState = ActorState.Active;
            return;
        }

        throw new InvalidOperationException(
                "Can not activate Actor '" ~ actorPath(actorInfo.actorType, actorId) ~ "'. Actor state is '" ~ to!string(
                actorState) ~ "'");
    }

    private void deactivate()
    {
        if (actorState == ActorState.Active)
        {            
            try
            {
                logInfo("Deactivating actor '" ~ actorPath(actorInfo.actorType, actorId) ~ "'...");
                actor.onDeactivate();
            }
            catch(Exception e)
            {
                actorState = ActorState.DeactivateFailed;
                throw e;
            }

            actorState = ActorState.Deactivated;
            return;
        }

        throw new InvalidOperationException(
                "Can not deactivate Actor '" ~ actorPath(actorInfo.actorType, actorId) ~ "'. Actor state is '" ~ to!string(
                actorState) ~ "'");
    }
}

private MethodInfo getMethodFor(ActorInfo actorInfo, ActorMessage actorMessage)
{
    foreach (methodInfo; actorInfo.methodInfos)
    {
        if (actorMessage.isForMethod(methodInfo))
        {
            return methodInfo;
        }
    }

    throw new InvalidActorMessageException(
            "Actor doesn't have a method named '" ~ actorMessage.methodName ~ "'.");
}

private bool isForMethod(ActorMessage actorMessage, MethodInfo methodInfo)
{
    if (actorMessage.methodName != methodInfo.name)
    {
        return false;
    }

    if (actorMessage.args.length != methodInfo.args.length)
    {
        return false;
    }

    foreach (i, arg; methodInfo.args)
    {
        if (actorMessage.args[i].type != arg)
        {
            return false;
        }
    }

    return true;
}

enum ActorState
{
    Created,
    Activating,
    ActivateFailed,
    Active,
    DeactivateFailed,
    Deactivated
}

class ActorInvokerStatus
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

class InvokerResponse
{
    Variant variant;

    this(Variant variant)
    {
        this.variant = variant;
    }
}

class InvokerMessage
{
    string messageType;

    this(string messageType)
    {
        this.messageType = messageType;
    }
}
