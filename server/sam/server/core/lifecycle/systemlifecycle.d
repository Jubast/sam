module sam.server.core.lifecycle.systemlifecycle;

import sam.common.enforce;
import sam.common.dependencyinjection;

import sam.server.core.lifecycle.core;

enum SystemLifecycleStage : int
{
    preBuild = 100, // Configure Options (default values, etc.)
    postBuild = 200, // Options Validation, Services Validation, etc.

    preStart = 300,
    internalServices = 400, // ActorSystem Internal Services (ActorCollector, ActorCollection, etc.)
    storageServices = 500, // Initialization of storage providers
    actorServices = 600, // Actor specific services (analytics, etc.)
    applicationServices = 700,

    starting = 800, // Clustering, HttpServer etc.
    started = 900,
    postStart = 1000,
}

class SystemLifecycleManager
{
    private Container m_container;
    private ILifecycleParticipant[] m_participants;
    private LifecycleObservable m_observable;

    this(Container container)
    {
        m_container = container.notNull;
        m_participants = m_container.resolveAll!(ILifecycleParticipant)();
        m_observable = new LifecycleObservable();

        foreach (participant; m_participants)
        {
            participant.participate(m_observable);
        }
    }

    void preBuild()
    {
        m_observable.start(SystemLifecycleStage.preBuild);
    }

    void postBuild()
    {
        m_observable.start(SystemLifecycleStage.postBuild);
    }

    void start()
    {
        m_observable.start(SystemLifecycleStage.preStart);
        m_observable.start(SystemLifecycleStage.internalServices);
        m_observable.start(SystemLifecycleStage.storageServices);
        m_observable.start(SystemLifecycleStage.actorServices);
        m_observable.start(SystemLifecycleStage.applicationServices);
        m_observable.start(SystemLifecycleStage.starting);
        m_observable.start(SystemLifecycleStage.started);
        m_observable.start(SystemLifecycleStage.postStart);
    }

    void stop()
    {
        m_observable.stop(SystemLifecycleStage.postStart);
        m_observable.stop(SystemLifecycleStage.started);
        m_observable.stop(SystemLifecycleStage.starting);
        m_observable.stop(SystemLifecycleStage.applicationServices);
        m_observable.stop(SystemLifecycleStage.actorServices);
        m_observable.stop(SystemLifecycleStage.storageServices);
        m_observable.stop(SystemLifecycleStage.internalServices);
        m_observable.stop(SystemLifecycleStage.preStart);

        m_observable.stop(SystemLifecycleStage.postBuild);
        m_observable.stop(SystemLifecycleStage.preBuild);
    }
}

version (unittest)
{
    import std.algorithm.searching;
    import fluent.asserts;
    import sam.common.dependencyinjection;

    class TestLifecycleResults
    {
        bool[int] startResult;
        bool[int] stopResult;
    }

    class TestSubscriber : ILifecycleParticipant
    {
        private TestLifecycleResults results;
        this(TestLifecycleResults results)
        {
            this.results = results;
        }

        void participate(ILifecycleObservable observable)
        {
            for (int i = 0; i < 2000; ++i)
            {
                // https://issues.dlang.org/show_bug.cgi?id=2043
                auto s = new Scope(i, j => 
                    observable.subscribe(j, { results.startResult[j] = true; }, { results.stopResult[j] = true; }));
                s.call();
            }
        }
    }
    
    class Scope
    {
        int args;
        void delegate(int) del;

        this(int args, void delegate(int) del)
        {
            this.del = del;
            this.args = args;
        }

        void call()
        {
            del(args);
        }
    }

    class TestNullSubscriber : ILifecycleParticipant
    {
        void participate(ILifecycleObservable observable)
        {
            for (int i = 0; i < 2000; ++i)
            {
                observable.subscribe(i, null, null);
            }
        }
    }

    SystemLifecycleManager prepareManager(ContainerBuilder container)
    {
        container.registerSingleton!(TestLifecycleResults)();
        container.registerSingleton!(ILifecycleParticipant, TestSubscriber)();
        container.registerSingleton!(ILifecycleParticipant, TestNullSubscriber)();

        container.registerSingleton!(SystemLifecycleManager)();
        return container.build().resolve!(SystemLifecycleManager)();
    }
}

@("SystemLifecycleManager should populate ILifecycleParticipant-s")
unittest
{
    auto containerBuilder = new ContainerBuilder;
    containerBuilder.registerSingleton!(TestLifecycleResults)();
    containerBuilder.registerSingleton!(ILifecycleParticipant, TestSubscriber)();
    containerBuilder.registerSingleton!(ILifecycleParticipant, TestNullSubscriber)();

    containerBuilder.registerSingleton!(SystemLifecycleManager)();

    auto manager = containerBuilder.build().resolve!(SystemLifecycleManager)();
    manager.m_participants.length.should.equal(2);
}

@("manager should start preBuild subscriptions")
unittest
{
    import std.stdio;

    auto containerBuilder = new ContainerBuilder;
    auto manager = prepareManager(containerBuilder);
    auto results = containerBuilder.build().resolve!(TestLifecycleResults)();

    manager.preBuild();
    results.stopResult.length.should.equal(0);
    results.startResult.length.should.equal(1);
    results.startResult[SystemLifecycleStage.preBuild].should.equal(true);
}

@("manager should start postBuild subscriptions")
unittest
{
    auto containerBuilder = new ContainerBuilder;
    auto manager = prepareManager(containerBuilder);
    auto results = containerBuilder.build().resolve!(TestLifecycleResults)();

    manager.postBuild();
    results.stopResult.length.should.equal(0);
    results.startResult.length.should.equal(1);
    results.startResult[SystemLifecycleStage.postBuild].should.equal(true);
}

@("manager should start start subscriptions")
unittest
{
    auto containerBuilder = new ContainerBuilder;
    auto manager = prepareManager(containerBuilder);
    auto results = containerBuilder.build().resolve!(TestLifecycleResults)();

    manager.start();
    results.stopResult.length.should.equal(0);
    results.startResult.length.should.equal(8);

    results.startResult[SystemLifecycleStage.preStart].should.equal(true);
    results.startResult[SystemLifecycleStage.internalServices].should.equal(true);
    results.startResult[SystemLifecycleStage.storageServices].should.equal(true);
    results.startResult[SystemLifecycleStage.actorServices].should.equal(true);
    results.startResult[SystemLifecycleStage.applicationServices].should.equal(true);
    results.startResult[SystemLifecycleStage.starting].should.equal(true);
    results.startResult[SystemLifecycleStage.started].should.equal(true);
    results.startResult[SystemLifecycleStage.postStart].should.equal(true);
}

@("manager stop should stop all")
unittest
{
    auto containerBuilder = new ContainerBuilder;
    auto manager = prepareManager(containerBuilder);
    auto results = containerBuilder.build().resolve!(TestLifecycleResults)();

    manager.stop();
    results.startResult.length.should.equal(0);
    results.stopResult.length.should.equal(10);
    
    results.stopResult[SystemLifecycleStage.postStart].should.equal(true);
    results.stopResult[SystemLifecycleStage.started].should.equal(true);
    results.stopResult[SystemLifecycleStage.starting].should.equal(true);
    results.stopResult[SystemLifecycleStage.applicationServices].should.equal(true);
    results.stopResult[SystemLifecycleStage.actorServices].should.equal(true);
    results.stopResult[SystemLifecycleStage.storageServices].should.equal(true);
    results.stopResult[SystemLifecycleStage.internalServices].should.equal(true);
    results.stopResult[SystemLifecycleStage.preStart].should.equal(true);

    results.stopResult[SystemLifecycleStage.postBuild].should.equal(true);
    results.stopResult[SystemLifecycleStage.postStart].should.equal(true);
}
