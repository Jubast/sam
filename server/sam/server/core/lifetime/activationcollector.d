module sam.server.core.lifetime.activationcollector;

import std.conv;
import std.datetime.stopwatch : StopWatch, AutoStart;
import std.datetime;
import core.time : msecs, minutes, seconds;

import vibe.core.core;
import vibe.core.log;
import vibe.core.sync;

import sam.common.actorresponse;
import sam.common.actormessage;

import sam.server.core.lifetime;
import sam.server.core.lifecycle;
import sam.server.core.options;

class ActivationCollector : ILifecycleParticipant
{
    private ActivationCollection m_collection;
    private ActorLifetimeOptions m_options;
    private TaskMutex m_mutex;
    private Task m_collectorTask;
    private bool stopping;

    this(ActivationCollection collection, ActorLifetimeOptions options)
    {
        this.m_mutex = new TaskMutex;
        this.m_collection = collection;
        this.m_options = options;
    }

    private void start()
    {
        logDebug("ActorCollector is starting...");

        m_collectorTask = runTask({
            while (true)
            {
                sleep(m_options.collectionDelay);

                synchronized (m_mutex)
                {
                    if (stopping)
                    {
                        return;
                    }

                    auto sw = StopWatch(AutoStart.yes);

                    logInfo("Searching for actors to deactivate...");
                    m_collection.removeAll(&canBeDeactivated);

                    sw.stop;
                    logInfo("Collecting actors took '" ~ to!string(
                        sw.peek.total!"msecs") ~ "' milliseconds");
                }
            }
        });
    }

    private void stop()
    {
        synchronized (m_mutex)
        {
            stopping = true;

            auto sw = StopWatch(AutoStart.yes);

            logInfo("ActorSystem is stopping, collecting all actors...");
            m_collection.removeAll(x => true);

            sw.stop;
            logInfo("Collecting actors took '" ~ to!string(
                    sw.peek.total!"msecs") ~ "' milliseconds");
        }

    }

    private bool canBeDeactivated(ActivationStatus activationStatus)
    {
        auto currTime = Clock.currTime(UTC()) -= m_options.maxIdle;

        // if actor is idle for more than m_options.maxIdle
        if (activationStatus.lastInteraction < currTime)
        {
            return true;
        }

        return false;
    }

    void participate(ILifecycleObservable observable)
    {
        observable.subscribe(SystemLifecycleStage.internalServices, &start, &stop);        
    }
}
