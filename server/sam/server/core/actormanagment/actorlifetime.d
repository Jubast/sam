module sam.server.core.actormanagment.actorlifetime;

import std.conv;
import std.datetime.stopwatch : StopWatch, AutoStart;
import std.datetime;
import core.time : msecs, minutes, seconds;
import vibe.core.core;
import vibe.core.log;
import std.variant;
import sam.common.actorresponse;
import sam.common.actormessage;
import sam.server.core.actormanagment.actorcollection;
import sam.server.core.actormanagment.activation;
import sam.server.core.actormanagment.actorinvoker;
import sam.server.core.actormanagment.options;

class ActorLifetime
{
    private ActorCollection m_collection;
    private ActorLifetimeOptions m_options;
    private Task m_removeActorsTask;
    
    this(ActorCollection collection, ActorLifetimeOptions options)
    {
        this.m_collection = collection;
        this.m_options = options;
    }

    void run()
    {
        m_removeActorsTask = runTask({
            while (true)
            {   
                sleep(m_options.collectionDelay);
                logInfo("Searching for actors to deactivate...");

                auto sw = StopWatch(AutoStart.yes);

                m_collection.removeAll(&canBeDeactivated);

                sw.stop;
                logInfo("Collecting actors took '" ~ to!string(sw.peek.total!"usecs") ~ "' microseconds");
            }
        });
    }

    private bool canBeDeactivated(ActorInvokerStatus invokerState)
    {
        auto currTime = Clock.currTime(UTC()) -= m_options.maxIdle;
        
        // if actor is idle for more than m_options.maxIdle
        if(invokerState.lastInteraction < currTime)
        {
            return true;
        }

        return false;
    }
}
