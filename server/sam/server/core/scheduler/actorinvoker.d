module sam.server.core.scheduler.actorinvoker;

import std.conv;
import std.datetime;

import vibe.core.log;

import sam.common.utils;
import sam.common.enforce;
import sam.common.interfaces.actor;
import sam.common.actormessage;
import sam.common.actorresponse;
import sam.common.exceptions;

import sam.server.core.introspection.actorinfo;
import sam.server.core.exceptions;

package:
class ActorInvoker
{
    IActor actor;
    string actorId;
    ActorInfo actorInfo;
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
        message.notNull;

        throwIfInvalidState();
        auto method = actorInfo.getMethodFor(message);
        return method.invoke(actor, message.args);
    }

    ManagerResponse managerInvoke(ManagerMessage message)
    {
        if (message.messageType == "activate")
        {
            activate();
        }
        else if (message.messageType == "deactivate")
        {
            deactivate();
        }

        return null;
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
            throw new ActorNotActivatedException("Actor '" ~ actorPath(actorInfo.actorType,
                    actorId)
                    ~ "' failed to activate. So it can't process messages. This exception should never happen.");
        }

        if (actorState == ActorState.DeactivateFailed)
        {
            // bug
            throw new ActorInvokerException("Actor '" ~ actorPath(actorInfo.actorType,
                    actorId)
                    ~ "' failed to deactivate. So it can't process messages. This exception should never happen.");
        }

        if (actorState == ActorState.Created)
        {
            // bug
            throw new ActorNotActivatedException("Actor '" ~ actorPath(actorInfo.actorType,
                    actorId)
                    ~ "' is not activated yet. So it can't process messages. This exception should never happen.");
        }

        if (actorState == ActorState.Activating)
        {
            // bug
            throw new ActorNotActivatedException("Actor '" ~ actorPath(actorInfo.actorType,
                    actorId)
                    ~ "' is beeing activated. So it can't process messages. This exception should never happen.");
        }

        if (actorState == ActorState.Deactivating)
        {
            // this exception should get caught, and a new actor should be created.
            throw new ActorDeactivatedException("Actor '" ~ actorPath(actorInfo.actorType, actorId)
                    ~ "' is beeing deactivated. So it can't process messages. This exception should never happen.");
        }
    }

    private void activate()
    {
        if (actorState == ActorState.Created)
        {
            actorState = ActorState.Activating;

            // TODO: Add retry policy
            try
            {
                logInfo("Activating actor '" ~ actorPath(actorInfo.actorType, actorId) ~ "'...");
                actor.onActivate();
            }
            catch (Exception e)
            {
                actorState = ActorState.ActivateFailed;
                throw e;
            }

            actorState = ActorState.Active;
            return;
        }

        throw new InvalidOperationException("Can not activate Actor '" ~ actorPath(actorInfo.actorType,
                actorId) ~ "'. Actor state is '" ~ to!string(actorState) ~ "'");
    }

    private void deactivate()
    {
        if (actorState == ActorState.Active)
        {
            actorState = ActorState.Deactivating;

            // TODO: Add retry policy
            try
            {
                logInfo("Deactivating actor '" ~ actorPath(actorInfo.actorType, actorId) ~ "'...");
                actor.onDeactivate();
            }
            catch (Exception e)
            {
                actorState = ActorState.DeactivateFailed;
                throw e;
            }

            actorState = ActorState.Deactivated;
            return;
        }

        throw new InvalidOperationException("Can not deactivate Actor '" ~ actorPath(actorInfo.actorType,
                actorId) ~ "'. Actor state is '" ~ to!string(actorState) ~ "'");
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
    Deactivating,
    DeactivateFailed,
    Deactivated
}

public class ManagerMessage
{
    string messageType;

    this(string messageType)
    {
        this.messageType = messageType;
    }
}

public class ManagerResponse
{
}
