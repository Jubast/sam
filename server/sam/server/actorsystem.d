module sam.server.actorsystem;

import std.conv;
import core.stdc.signal;

import eventcore.core;
import vibe.core.core;
import vibe.core.log;
import vibe.core.sync;

import sam.common.enforce;
import sam.common.interfaces.actorsystem;
import sam.common.interfaces.messagereceiver;
import sam.common.interfaces.messagesender;
import sam.common.interfaces.actor;
import sam.common.dependencyinjection;

import sam.server.core.options;
import sam.server.core.lifetime;
import sam.server.core.lifecycle;
import sam.server.core.introspection;
import sam.server.core.actorprovider;
import sam.server.core.pipelines.messagereceiver;

import sam.client.messagesender;
import sam.client.actorsystem;

class ActorSystem : IActorSystem
{
    private Container m_container;
    private ActorRegistry m_actorRegistry;
    private shared(ManualEvent) m_event = createSharedManualEvent();
    private Task m_exitTask;

    Container container()
    {
        return m_container;
    }

    this(Container container, ActorRegistry actorRegistry)
    {
        this.m_container = container.notNull;
        this.m_actorRegistry = actorRegistry.notNull;
    }

    void start()
    {
        setExitListener();        

        // Will get started once the event loop starts.
        auto startTask = runTask({
            try{
                logInfo("Starting the actor system...");
                auto manager = m_container.resolve!(SystemLifecycleManager)();
                manager.start();
            }
            catch(Exception e)
            {                
                logError("ActorSystem start failed. " ~ e.toString());
                exitEventLoop();
            }
        });        
    }

    void stop()
    {
        logDebug("Stopping the actor system...");
        // Event loop should be running here.
        auto manager = m_container.resolve!(SystemLifecycleManager)();
        manager.stop();

        logInfo("Actor system stopped.");
    }

    private void setExitListener()
    {
        eventDriver.signals.listen(SIGINT, &onExit);
        m_exitTask = runTask({
            m_event.wait();
            stop();
            exitEventLoop();
        });
    }    
    
    private void onExit(SignalListenID id, SignalStatus status, int i)
    nothrow @safe
    {
        import std.conv;
        logDebug("Sig '" ~ i.to!string ~ "' received.");
                
        m_event.emit();
    }    
}