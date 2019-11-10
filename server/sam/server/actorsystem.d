module sam.server.actorsystem;

import poodinis;
import vibe.core.core : runApplication;

import sam.common.enforce;
import sam.common.interfaces.messagereceiver;
import sam.common.interfaces.messagesender;
import sam.common.interfaces.actor;

import sam.server.core.actormanagment.actorcollection;
import sam.server.core.actormanagment.actorprovider;
import sam.server.core.actormanagment.actorregistry;
import sam.server.core.pipelines.messagereceiver;
import sam.server.core.actormanagment.actorlifetime;
import sam.server.core.actormanagment.options;

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

    ActorSystemClient clientOf()
    {
        return new ActorSystemClient(m_container.resolve!IMessageSender);
    }
}

class ActorSystemBuilder
{
    private shared DependencyContainer m_container;
    private ActorRegistry m_actorRegistry;

    shared(DependencyContainer) container() { return m_container; }

    this()
    {
        m_container = new shared DependencyContainer;
        m_container.register!DependencyContainer().existingInstance(cast(DependencyContainer) m_container);
        m_container.register!ActorRegistry;
        m_actorRegistry = m_container.resolve!ActorRegistry;
    }

    ActorSystemBuilder register(TIActor: IActor, TActor: IActor)()
    {
        m_actorRegistry.register!(TIActor, TActor)();
        return this;
    }

    ActorSystem build()
    {        
        return new ActorSystem(m_container, m_actorRegistry);
    }
}

ActorSystemBuilder UseInMemoryActorSystem(ActorSystemBuilder builder)
{
    builder.container.UseDefaultOptions();
    builder.container.register!(IMessageSender, MessageSender);
    builder.container.register!(IMessageReceiver, MessageReceiver);
    builder.container.register!(ActorProvider);
    builder.container.register!(ActorCollection);
    builder.container.register!(ActorLifetime);

    // TODO: create a lifecycle (PreBuild, PostBuild, PreRun, PostRun)
    auto registry = builder.container.resolve!(ActorRegistry);
    auto collection = builder.container.resolve!(ActorCollection);
    collection.createDirectories(registry); // PostBuild

    auto lifetime = builder.container.resolve!(ActorLifetime);
    lifetime.run;

    return builder;
}

private void UseDefaultOptions(shared(DependencyContainer) contianer)
{
    contianer.register!ActorLifetimeOptions();
}