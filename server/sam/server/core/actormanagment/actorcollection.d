module sam.server.core.actormanagment.actorcollection;

import poodinis;

import vibe.core.core;
import vibe.core.sync;
import vibe.core.log;

import sam.common.enforce;
import sam.common.actormessage;
import sam.common.exceptions;

import sam.server.core.containers.aa;
import sam.server.core.containers.concurrentaa;
import sam.server.core.actormanagment.actorinfo;
import sam.server.core.actormanagment.activation;
import sam.server.core.actormanagment.actorregistry;
import sam.server.core.actormanagment.actorinvoker;
import sam.server.core.lifecycle;

class ActorCollection : ILifecycleParticipant
{
    private shared DependencyContainer m_container;
    private LockabileAA!(TypeInfo, ActorDirectory) m_directories;
    private bool stopping;

    this(DependencyContainer container)
    {
        this.m_container = cast(shared) container.notNull;
    }    

    Activation getOrAdd(TypeInfo actorType, string actorId, lazy ActorInfo lazyActorInfo)
    {
        m_directories.notNull;
        actorType.notNull;
        actorId.notNull;
        lazyActorInfo.notNull;

        if(!stopping)
        {
            return m_directories[actorType].getOrAdd(actorId, lazyActorInfo);
        }

        throw new InvalidOperationException("Request rejected because ActorCollection is stopping");
    }

    void removeAll(bool delegate(ActorInvokerStatus) predicate)
    {
        foreach (directory; m_directories)
        {
            directory.removeAll(predicate);
        }
    }

    private void init()
    {
        logInfo("ActorCollection is initializing...");
        this.m_directories = new LockabileAA!(TypeInfo, ActorDirectory);
        foreach (actorType; m_container.resolve!(ActorRegistry)().registerdTypes())
        {
            m_directories[actorType] = new ActorDirectory(actorType, m_container);
        }
        m_directories.lock();
    }

    private void stop()
    {
        logInfo("ActorCollection is stopping...");
        stopping = true;
    }

    void participate(ILifecycleObservable observable)
    {
        observable.subscribe(SystemLifecycleStage.PreStart, &init, &stop);
    }
}

class ActorDirectory
{
    private TypeInfo m_actorType;
    private shared DependencyContainer m_container;
    private TaskConcurrentAA!(string, Activation) m_activations;

    this(TypeInfo actorType, shared DependencyContainer container)
    {
        this.m_actorType = actorType;
        this.m_activations = new TaskConcurrentAA!(string, Activation);
    }

    Activation getOrAdd(string actorId, lazy ActorInfo lazyActorInfo)
    {
        return m_activations.getOrAdd(actorId, () => activationDelegate(actorId, lazyActorInfo));
    }

    void removeAll(bool delegate(ActorInvokerStatus) predicate)
    {
        Activation[string] activations = m_activations.dupUnsafe;

        Task[] tasks;
        foreach (keyValue; activations.byKeyValue)
        {
            tasks ~= runTask({
                auto actorId = keyValue.key;
                auto activation = keyValue.value;

                auto state = activation.invokerState().variant.get!ActorInvokerStatus;
                if (predicate(state))
                {
                    activation.deactivate();
                    m_activations.remove(actorId);
                }

            });
        }

        foreach (task; tasks)
        {
            task.join();
        }
    }

    private Activation activationDelegate(string actorId, lazy ActorInfo lazyActorInfo)
    {
        auto actorInfo = lazyActorInfo();
        auto actor = actorInfo.resolver()(m_container, actorId);
        auto activation = new Activation(actor, actorId, actorInfo);

        // TODO: don't leave the activate task in the void
        runTask({ activation.activate(); });
        return activation;
    }
}

version (unittest)
{
    import fluent.asserts;
    import sam.common.interfaces.actor;
    import std.uuid;

    interface ITestActor : IActor
    {
        string returnHelloWorld();
    }

    class TestActor : IActor
    {
        string returnHelloWorld()
        {
            return "HelloWorld";
        }

        void onActivate()
        {
        }

        void onDeactivate()
        {
        }
    }

    ActorCollection preparedActorCollection()
    {
        auto dependencies = new shared DependencyContainer();
        auto actorRegistry = new ActorRegistry(cast(DependencyContainer) dependencies);
        actorRegistry.register!(ITestActor, TestActor);
        dependencies.register!ActorRegistry().existingInstance(actorRegistry);

        auto actorCollection = new ActorCollection(cast(DependencyContainer) dependencies);
        actorCollection.init();
        return actorCollection;
    }
}

@("createDirectories should create Directories from ActorRegistry and lock")
unittest
{
    auto dependencies = new shared DependencyContainer();
    auto actorRegistry = new ActorRegistry(cast(DependencyContainer) dependencies);
    actorRegistry.register!(ITestActor, TestActor);
    dependencies.register!ActorRegistry().existingInstance(actorRegistry);

    auto actorCollection = new ActorCollection(cast(DependencyContainer) dependencies);
    actorCollection.init();

    actorCollection.m_directories.length.should.equal(1);
    actorCollection.m_directories[typeid(ITestActor)].should.not.equal(null);
    actorCollection.m_directories.locked.should.equal(true);
}

@("getOrAdd should get directory and create activation")
unittest
{
    auto actorCollection = preparedActorCollection();
    auto actorInfo = actorInfo!(ITestActor, TestActor)();

    auto id = randomUUID.toString;
    auto newActor = actorCollection.getOrAdd(typeid(ITestActor), id, actorInfo);

    auto directory = *(typeid(ITestActor) in actorCollection.m_directories);
    directory.m_activations.length.should.equal(1);

    auto actorPtr = id in directory.m_activations;
    assert(actorPtr !is null, "Activation was not created!");
}

@("getOrAdd should return existing activation")
unittest
{
    auto dependencies = new shared DependencyContainer();
    auto actorCollection = preparedActorCollection();
    auto actorInfo = actorInfo!(ITestActor, TestActor)();

    auto id = randomUUID.toString;
    auto actor = actorInfo.resolver()(dependencies, id);
    auto activation = new Activation(actor, id, actorInfo);
    actorCollection.m_directories[typeid(ITestActor)].m_activations.getOrAdd(id, () => activation);

    auto returnedActivation = actorCollection.getOrAdd(typeid(ITestActor), id, actorInfo);
    actorCollection.m_directories.length.should.equal(1);
    (activation == returnedActivation).should.equal(true);
}

@("removeAll with true predicate should remove all")
unittest
{
    auto actorCollection = preparedActorCollection();
    auto actorInfo = actorInfo!(ITestActor, TestActor)();

    actorCollection.getOrAdd(typeid(ITestActor), randomUUID.toString, actorInfo);
    actorCollection.getOrAdd(typeid(ITestActor), randomUUID.toString, actorInfo);
    actorCollection.getOrAdd(typeid(ITestActor), randomUUID.toString, actorInfo);

    actorCollection.m_directories[typeid(ITestActor)].m_activations.length.should.equal(3);
    runTask({ actorCollection.removeAll(x => true); exitEventLoop; });

    runEventLoop;

    actorCollection.m_directories[typeid(ITestActor)].m_activations.length.should.equal(0);
}

@("removeAll with false predicate should not remove any")
unittest
{
    auto actorCollection = preparedActorCollection();
    auto actorInfo = actorInfo!(ITestActor, TestActor)();

    actorCollection.getOrAdd(typeid(ITestActor), randomUUID.toString, actorInfo);
    actorCollection.getOrAdd(typeid(ITestActor), randomUUID.toString, actorInfo);
    actorCollection.getOrAdd(typeid(ITestActor), randomUUID.toString, actorInfo);

    actorCollection.m_directories[typeid(ITestActor)].m_activations.length.should.equal(3);
    runTask({ actorCollection.removeAll(x => false); exitEventLoop; });

    runEventLoop;

    actorCollection.m_directories[typeid(ITestActor)].m_activations.length.should.equal(3);
}

@("removeAll with predicate should remove")
unittest
{
    import std.stdio;
    import std.conv;

    auto actorCollection = preparedActorCollection();
    auto actorInfo = actorInfo!(ITestActor, TestActor)();

    auto knownId = randomUUID.toString;
    actorCollection.getOrAdd(typeid(ITestActor), knownId, actorInfo);
    actorCollection.getOrAdd(typeid(ITestActor), randomUUID.toString, actorInfo);
    actorCollection.getOrAdd(typeid(ITestActor), randomUUID.toString, actorInfo);

    actorCollection.m_directories[typeid(ITestActor)].m_activations.length.should.equal(3);
    runTask({ actorCollection.removeAll(x => x.actorId == knownId); exitEventLoop; });

    runEventLoop;

    actorCollection.m_directories[typeid(ITestActor)].m_activations.length.should.equal(2);
}
