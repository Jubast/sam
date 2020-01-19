module sam.server.actorsystembuilder;

import vibe.core.core;
import vibe.core.log;

import sam.common.enforce;
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
import sam.server.actorsystem;
import eventcore.core;

class ActorSystemBuilder
{
    private ContainerBuilder m_containerBuilder;
    private ActorRegistry m_actorRegistry;

    ContainerBuilder container()
    {
        return m_containerBuilder;
    }

    this()
    {
        m_containerBuilder = new ContainerBuilder;
        m_actorRegistry = new ActorRegistry;
        m_containerBuilder.registerExisting(m_actorRegistry);
    }

    ActorSystemBuilder register(TIActor : IActor, TActor : IActor)()
    {
        m_actorRegistry.register!(TIActor, TActor)();
        return this;
    }

    ActorSystem build()
    {
        auto container = m_containerBuilder.build();
        auto manager = container.resolve!(SystemLifecycleManager);
        manager.preBuild();

        auto actorSystem = new ActorSystem(container, m_actorRegistry);

        manager.postBuild();
        return actorSystem;
    }
}

ActorSystemBuilder UseInMemoryActorSystem(ActorSystemBuilder builder)
{
    builder.container.UseDefaultOptions();
    builder.container.UseCoreServices();

    builder.container.registerSingleton!(IMessageSender, MessageSender);
    builder.container.registerSingleton!(IMessageReceiver, MessageReceiver);
    builder.container.registerSingleton!(ActorProvider);

    return builder;
}

private void UseCoreServices(ContainerBuilder contianer)
{
    contianer.registerSingleton!(SystemLifecycleManager);
    contianer.registerLifecycleParticipant!(ActivationCollection);
    contianer.registerLifecycleParticipant!(ActivationCollector);
}

private void UseDefaultOptions(ContainerBuilder contianer)
{
    contianer.registerSingleton!ActorLifetimeOptions();
}

private void registerLifecycleParticipant(TService : ILifecycleParticipant)(ContainerBuilder container)
{
    container.registerSingleton!(TService)();
    container.registerExisting!(ILifecycleParticipant, TService)(c => c.resolve!TService);
}