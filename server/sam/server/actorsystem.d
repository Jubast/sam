module sam.server.actorsystem;

import poodinis;
import vibe.core.core;
import vibe.core.log;

import sam.common.enforce;
import sam.common.interfaces.messagereceiver;
import sam.common.interfaces.messagesender;
import sam.common.interfaces.actor;

import sam.server.core.actormanagment.actorcollection;
import sam.server.core.actormanagment.actorprovider;
import sam.server.core.actormanagment.actorregistry;
import sam.server.core.pipelines.messagereceiver;
import sam.server.core.actormanagment.actorcollector;
import sam.server.core.actormanagment.options;
import sam.server.core.lifecycle;

import sam.client.messagesender;
import sam.client.actorsystem;

class ActorSystem
{
    private shared DependencyContainer m_container;
    private ActorRegistry m_actorRegistry;

    this(shared DependencyContainer container, ActorRegistry actorRegistry)
    {
        this.m_container = container.notNull;
        this.m_actorRegistry = actorRegistry.notNull;
    }

    /** 
     * Starts the actors system and the vibe-d eventloop
     */
    void start(string[]* args_out = null)
    {
        logInfo("Starting the actor system...");
        auto startTask = runTask({
            auto notifier = m_container.resolve!(SystemLifecycleNotifier);
            notifier.notifyStarting();
            notifier.notifyStarted();
        });
                
        switchToTask(startTask);
        runApplication(args_out);
    }

    /** 
     * Stops the actors system and the vibe-d eventloop
     */
    void stop()
    {
        logInfo("Stopping the actor system...");
        auto stopTask = runTask({
            auto notifier = m_container.resolve!(SystemLifecycleNotifier);
            notifier.notifyStopping();

            logInfo("Actor system stopped.");
            exitEventLoop();
        });

        // FIXME: Check if event loop is already running!
        runEventLoop();
    }

    ActorSystemClient clientOf()
    {
        return new ActorSystemClient(m_container.resolve!IMessageSender);
    }
}

class ActorSystemBuilder
{
    private shared DependencyContainer m_container;
    private ActorRegistry m_actorRegistry;

    shared(DependencyContainer) container()
    {
        return m_container;
    }

    this()
    {
        m_container = new shared DependencyContainer;
        m_container.register!DependencyContainer()
            .existingInstance(cast(DependencyContainer) m_container);
        m_container.register!ActorRegistry;
        m_actorRegistry = m_container.resolve!ActorRegistry;
    }

    ActorSystemBuilder register(TIActor : IActor, TActor : IActor)()
    {
        m_actorRegistry.register!(TIActor, TActor)();
        return this;
    }

    ActorSystem build()
    {
        auto notifier = m_container.resolve!(SystemLifecycleNotifier);
        notifier.notifyBuilding();

        auto actorSystem = new ActorSystem(m_container, m_actorRegistry);

        notifier.notifyBuilt();
        return actorSystem;
    }
}

ActorSystemBuilder UseInMemoryActorSystem(ActorSystemBuilder builder)
{
    builder.container.UseDefaultOptions();
    builder.container.UseCoreServices();

    builder.container.register!(IMessageSender, MessageSender);
    builder.container.register!(IMessageReceiver, MessageReceiver);
    builder.container.register!(ActorProvider);

    return builder;
}

private void UseCoreServices(shared(DependencyContainer) contianer)
{
    contianer.register!(SystemLifecycleNotifier);
    contianer.registerLifecycleParticipant!(ActorCollection);
    contianer.registerLifecycleParticipant!(ActorCollector);
}

private void UseDefaultOptions(shared(DependencyContainer) contianer)
{
    contianer.register!ActorLifetimeOptions();
}

private void registerLifecycleParticipant(TService : ILifecycleParticipant)(
        shared(DependencyContainer) container)
{
    container.register!(TService)();
    container.register!(ILifecycleParticipant, TService)();
}
