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
import sam.server.core.actormanagment.actormailbox;
import sam.server.core.actormanagment.actormanager;

class ActorLifetime
{
    private ActorCollection collection;
    private Task removeActorsTask;

    // TODO: configure lifetime checking (frequency, alive_duration) via options
    this(ActorCollection collection)
    {
        this.collection = collection;
    }

    void run()
    {
        removeActorsTask = runTask({
            while (true)
            {   
                sleep(5000.msecs);                 
                logInfo("Searching for actors to deactivate...");

                auto sw = StopWatch(AutoStart.no);
                sw.start;
                collection.removeIf(&canBeDeactivated);               

                sw.stop;
                logInfo("Collecting actors took '" ~ to!string(sw.peek.total!"msecs") ~ "'msecs");
            }
        });
    }

    private static bool canBeDeactivated(ActorMailbox mailbox)
    {
        auto managerState = mailbox.put(managerState).getResult.variant.get!ActorManagerState;
        auto currTime = Clock.currTime(UTC()) -= 5.minutes;

        // if actor is alive longer than 5 minutes
        if(managerState.lastInteraction < currTime)
        {
            logInfo("Deactivating actor..");
            mailbox.put(deactivateActorMessage);
            return true;
        }

        return false;
    }

    private static ActorMessage deactivateActorMessage()
    {
        return new ActorMessage(typeid(Object), "unknown", "onDeactivate", null);
    }

    private static ActorMessage managerState()
    {
        return new ActorMessage(typeid(Object), "unknown", ":managerState:", null);
    }
}
