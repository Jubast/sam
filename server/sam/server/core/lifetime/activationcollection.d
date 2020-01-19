module sam.server.core.lifetime.activationcollection;

import std.typecons;

import vibe.core.core;
import vibe.core.sync;
import vibe.core.log;

import sam.common.enforce;
import sam.common.actormessage;
import sam.common.exceptions;
import sam.common.dependencyinjection;

import sam.server.core.containers.aa;
import sam.server.core.containers.concurrentaa;
import sam.server.core.introspection;
import sam.server.core.lifetime;
import sam.server.core.lifecycle;
import sam.server.core.scheduler;

class ActivationCollection : ILifecycleParticipant
{
    private Container m_container;
    private LockabileAA!(TypeInfo, ActivationPartition) m_partitions;
    private bool stopping;

    this(Container container)
    {
        this.m_container = container.notNull;
    }

    Activation getOrAdd(TypeInfo actorType, string actorId, lazy ActorInfo lazyActorInfo)
    {
        actorType.notNull;
        actorId.notNull;
        lazyActorInfo.notNull;

        if (stopping)
        {
            throw new InvalidOperationException("Request rejected because ActivationCollection is stopping");
        }

        return m_partitions[actorType].getOrAdd(actorId, lazyActorInfo);        
    }

    void removeAll(bool delegate(ActivationStatus) predicate)
    {
        foreach (partition; m_partitions)
        {
            partition.removeAll(predicate);
        }
    }

    private void init()
    {
        logDebug("ActivationCollection is initializing...");
        this.m_partitions = new LockabileAA!(TypeInfo, ActivationPartition);
        foreach (actorType; m_container.resolve!(ActorRegistry)().registerdTypes())
        {
            m_partitions[actorType] = new ActivationPartition(actorType, m_container);
        }
        m_partitions.lock();
    }

    private void stop()
    {
        logDebug("ActivationCollection is stopping...");
        stopping = true;
    }

    void participate(ILifecycleObservable observable)
    {
        observable.subscribe(SystemLifecycleStage.internalServices, &init, &stop);
    }
}

class ActivationPartition
{
    private TypeInfo m_actorType;
    private Container m_container;
    private TaskConcurrentAA!(string, Activation) m_activations;

    this(TypeInfo actorType, Container container)
    {
        this.m_actorType = actorType;
        this.m_activations = new TaskConcurrentAA!(string, Activation);
    }

    Activation getOrAdd(string actorId, lazy ActorInfo lazyActorInfo)
    {
        return m_activations.getOrAdd(actorId, () => activationDelegate(actorId, lazyActorInfo));
    }

    void removeAll(bool delegate(ActivationStatus) predicate)
    {
        Activation[string] activations = m_activations.dupUnsafe;

        Task[] tasks;
        foreach (keyValue; activations.byKeyValue)
        {
            tasks ~= runTask({
                auto actorId = keyValue.key;
                auto activation = keyValue.value;

                if (predicate(activation.status))
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

    private Tuple!(Activation, Task) activationDelegate(string actorId, lazy ActorInfo lazyActorInfo)
    {
        auto actorInfo = lazyActorInfo();
        auto actor = actorInfo.resolver()(m_container, actorId);
        auto activation = new Activation(actor, actorId, actorInfo);

        auto task = runTask({ activation.activate(); });

        return Tuple!(Activation, Task)(activation, task);
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

    ActivationCollection preparedActivationCollection()
    {
        auto builder = new ContainerBuilder();
        auto actorRegistry = new ActorRegistry;
        actorRegistry.register!(ITestActor, TestActor);
        builder.registerExisting(actorRegistry);

        auto activationCollection = new ActivationCollection(builder.build());
        activationCollection.init();

        return activationCollection;
    }
}

@("createPartitions should create Parititons from ActorRegistry and lock")
unittest
{
    auto builder = new ContainerBuilder();
    auto actorRegistry = new ActorRegistry;
    actorRegistry.register!(ITestActor, TestActor);
    builder.registerExisting(actorRegistry);

    auto activationCollection = new ActivationCollection(builder.build());
    activationCollection.init();

    activationCollection.m_partitions.length.should.equal(1);
    activationCollection.m_partitions[typeid(ITestActor)].should.not.equal(null);
    activationCollection.m_partitions.locked.should.equal(true);
}

@("getOrAdd should get partition and create activation")
unittest
{
    auto activationCollection = preparedActivationCollection();
    auto actorInfo = actorInfo!(ITestActor, TestActor)();

    auto id = randomUUID.toString;
    auto newActor = activationCollection.getOrAdd(typeid(ITestActor), id, actorInfo);

    auto partition = *(typeid(ITestActor) in activationCollection.m_partitions);
    partition.m_activations.length.should.equal(1);

    auto actorPtr = id in partition.m_activations;
    assert(actorPtr !is null, "Activation was not created!");
}

@("getOrAdd should return existing activation")
unittest
{
    auto builder = new Container();
    auto activationCollection = preparedActivationCollection();
    auto actorInfo = actorInfo!(ITestActor, TestActor)();

    auto id = randomUUID.toString;
    auto actor = actorInfo.resolver()(builder, id);
    auto activation = new Activation(actor, id, actorInfo);
    activationCollection.m_partitions[typeid(ITestActor)].m_activations.getOrAdd(id,
            () => Tuple!(Activation, Task)(activation, Task.init));

    auto returnedActivation = activationCollection.getOrAdd(typeid(ITestActor), id, actorInfo);
    activationCollection.m_partitions.length.should.equal(1);
    (activation == returnedActivation).should.equal(true);
}

@("removeAll with true predicate should remove all")
unittest
{
    auto activationCollection = preparedActivationCollection();
    auto actorInfo = actorInfo!(ITestActor, TestActor)();

    activationCollection.getOrAdd(typeid(ITestActor), randomUUID.toString, actorInfo);
    activationCollection.getOrAdd(typeid(ITestActor), randomUUID.toString, actorInfo);
    activationCollection.getOrAdd(typeid(ITestActor), randomUUID.toString, actorInfo);

    activationCollection.m_partitions[typeid(ITestActor)].m_activations.length.should.equal(3);
    runTask({ activationCollection.removeAll(x => true); exitEventLoop; });

    runEventLoop;

    activationCollection.m_partitions[typeid(ITestActor)].m_activations.length.should.equal(0);
}

@("removeAll with false predicate should not remove any")
unittest
{
    auto activationCollection = preparedActivationCollection();
    auto actorInfo = actorInfo!(ITestActor, TestActor)();

    activationCollection.getOrAdd(typeid(ITestActor), randomUUID.toString, actorInfo);
    activationCollection.getOrAdd(typeid(ITestActor), randomUUID.toString, actorInfo);
    activationCollection.getOrAdd(typeid(ITestActor), randomUUID.toString, actorInfo);

    activationCollection.m_partitions[typeid(ITestActor)].m_activations.length.should.equal(3);
    runTask({ activationCollection.removeAll(x => false); exitEventLoop; });

    runEventLoop;

    activationCollection.m_partitions[typeid(ITestActor)].m_activations.length.should.equal(3);
}

@("removeAll with predicate should remove")
unittest
{
    import std.stdio;
    import std.conv;

    auto activationCollection = preparedActivationCollection();
    auto actorInfo = actorInfo!(ITestActor, TestActor)();

    auto knownId = randomUUID.toString;
    activationCollection.getOrAdd(typeid(ITestActor), knownId, actorInfo);
    activationCollection.getOrAdd(typeid(ITestActor), randomUUID.toString, actorInfo);
    activationCollection.getOrAdd(typeid(ITestActor), randomUUID.toString, actorInfo);

    activationCollection.m_partitions[typeid(ITestActor)].m_activations.length.should.equal(3);
    runTask({
        activationCollection.removeAll(x => x.actorId == knownId);
        exitEventLoop;
    });

    runEventLoop;

    activationCollection.m_partitions[typeid(ITestActor)].m_activations.length.should.equal(2);
}
