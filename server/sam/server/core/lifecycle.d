module sam.server.core.lifecycle;

import sam.common.enforce;
import std.stdio;
import poodinis;

interface ILifecycleParticipant
{
    void participate(ILifecycleObservable observable);
}

enum SystemLifecycleStage
{
    PreBuild,
    PostBuild,
    PreStart,
    PostStart,
}

interface ILifecycleObservable
{
    void subscribe(SystemLifecycleStage stage, void delegate() onStart, void delegate() onStop);
}

private class LifecycleObservable : ILifecycleObservable
{
    private Subscription[] m_subscriptions;

    void subscribe(SystemLifecycleStage stage, void delegate() onStart, void delegate() onStop)
    {
        m_subscriptions ~= new Subscription(stage, onStart, onStop);
    }

    void notifyStarted(SystemLifecycleStage stage)
    {
        foreach (subscription; m_subscriptions)
        {
            if (subscription.stage == stage)
            {
                subscription.onStart();
            }
        }
    }

    void notifyStopped(SystemLifecycleStage stage)
    {
        foreach (subscription; m_subscriptions)
        {
            if (subscription.stage == stage)
            {
                subscription.onStop();
            }
        }
    }
}

private class Subscription
{
    private SystemLifecycleStage m_stage;
    private void delegate() m_onStart;
    private void delegate() m_onStop;

    SystemLifecycleStage stage()
    {
        return m_stage;
    }

    this(SystemLifecycleStage stage, void delegate() onStart, void delegate() onStop)
    {
        this.m_stage = stage;
        this.m_onStart = onStart;
        this.m_onStop = onStop;
    }

    void onStart()
    {
        if (m_onStart)
        {
            m_onStart();
        }
    }

    void onStop()
    {
        if (m_onStop)
        {
            m_onStop();
        }
    }
}

class SystemLifecycleNotifier
{
    private shared DependencyContainer m_container;
    private ILifecycleParticipant[] m_participants;
    private LifecycleObservable m_observable;

    this(DependencyContainer container)
    {
        m_container = cast(shared(DependencyContainer)) container.notNull;
        m_participants = m_container.resolveAll!(ILifecycleParticipant)();
        m_observable = new LifecycleObservable();

        foreach (participant; m_participants)
        {
            participant.participate(m_observable);
        }
    }

    void notifyBuilding()
    {
        m_observable.notifyStarted(SystemLifecycleStage.PreBuild);
    }

    void notifyBuilt()
    {
        m_observable.notifyStarted(SystemLifecycleStage.PostBuild);
    }

    void notifyStarting()
    {
        m_observable.notifyStarted(SystemLifecycleStage.PreStart);
    }

    void notifyStarted()
    {
        m_observable.notifyStarted(SystemLifecycleStage.PostStart);
    }

    void notifyStopping()
    {
        m_observable.notifyStopped(SystemLifecycleStage.PostStart);
        m_observable.notifyStopped(SystemLifecycleStage.PreStart);
        m_observable.notifyStopped(SystemLifecycleStage.PostBuild);
        m_observable.notifyStopped(SystemLifecycleStage.PreBuild);
    }
}

version (unittest)
{
    import std.algorithm.searching;
    import fluent.asserts;
    import poodinis;

    class TestLifecycleResults
    {
        private bool preBuildStarted;
        private bool preBuildStopped;

        private bool postBuildStarted;
        private bool postBuildStopped;

        private bool preStartStarted;
        private bool preStartStopped;

        private bool postStartStarted;
        private bool postStartStopped;
    }

    class TestPreBuild : ILifecycleParticipant
    {
        private TestLifecycleResults results;
        this(TestLifecycleResults results)
        {
            this.results = results;
        }

        void participate(ILifecycleObservable observable)
        {
            observable.subscribe(SystemLifecycleStage.PreBuild, &start, &stop);
        }

        void start()
        {
            results.preBuildStarted = true;
        }

        void stop()
        {
            results.preBuildStopped = true;
        }
    }

    class TestPostBuild : ILifecycleParticipant
    {
        private TestLifecycleResults results;
        this(TestLifecycleResults results)
        {
            this.results = results;
        }

        void participate(ILifecycleObservable observable)
        {
            observable.subscribe(SystemLifecycleStage.PostBuild, &start, &stop);
        }

        void start()
        {
            results.postBuildStarted = true;
        }

        void stop()
        {
            results.postBuildStopped = true;
        }
    }

    class TestPostBuildNull : ILifecycleParticipant
    {
        void participate(ILifecycleObservable observable)
        {
            observable.subscribe(SystemLifecycleStage.PostBuild, null, null);
        }
    }

    class TestPreStart : ILifecycleParticipant
    {
        private TestLifecycleResults results;
        this(TestLifecycleResults results)
        {
            this.results = results;
        }

        void participate(ILifecycleObservable observable)
        {
            observable.subscribe(SystemLifecycleStage.PreStart, &start, &stop);
        }

        void start()
        {
            results.preStartStarted = true;
        }

        void stop()
        {
            results.preStartStopped = true;
        }
    }

    class TestPostStart : ILifecycleParticipant
    {
        private TestLifecycleResults results;
        this(TestLifecycleResults results)
        {
            this.results = results;
        }

        void participate(ILifecycleObservable observable)
        {
            observable.subscribe(SystemLifecycleStage.PostStart, &start, &stop);
        }

        void start()
        {
            results.postStartStarted = true;
        }

        void stop()
        {
            results.postStartStopped = true;
        }
    }

    SystemLifecycleNotifier prepareNotifier(shared(DependencyContainer) container)
    {
        container.register!DependencyContainer()
            .existingInstance(cast(DependencyContainer) container);
        container.register!(TestLifecycleResults)();

        container.register!(TestPreBuild)();
        container.register!(ILifecycleParticipant, TestPreBuild)();

        container.register!(TestPostBuild)();
        container.register!(ILifecycleParticipant, TestPostBuild)();

        container.register!(TestPostBuildNull)();
        container.register!(ILifecycleParticipant, TestPostBuildNull)();

        container.register!(TestPreStart)();
        container.register!(ILifecycleParticipant, TestPreStart)();

        container.register!(TestPostStart)();
        container.register!(ILifecycleParticipant, TestPostStart)();

        container.register!(SystemLifecycleNotifier)();
        return container.resolve!(SystemLifecycleNotifier)();
    }
}

@("SystemLifecycleNotifier should populate ILifecycleParticipant-s")
unittest
{
    auto container = new shared DependencyContainer;
    container.register!(DependencyContainer)()
        .existingInstance(cast(DependencyContainer) container);
    container.register!(TestLifecycleResults)();

    container.register!(TestPreBuild)();
    container.register!(ILifecycleParticipant, TestPreBuild)();

    container.register!(TestPostBuild)();
    container.register!(ILifecycleParticipant, TestPostBuild)();

    container.register!(SystemLifecycleNotifier)();
    auto notifier = container.resolve!(SystemLifecycleNotifier)();
    notifier.m_participants.length.should.equal(2);
}

@("notifier should start preBuild subscriptions")
unittest
{
    auto container = new shared DependencyContainer;
    auto notifier = prepareNotifier(container);
    auto results = container.resolve!(TestLifecycleResults)();

    notifier.notifyBuilding();
    results.preBuildStarted.should.equal(true);
    results.preBuildStopped.should.equal(false);

    results.postBuildStarted.should.equal(false);
    results.postBuildStopped.should.equal(false);

    results.preStartStarted.should.equal(false);
    results.preStartStopped.should.equal(false);

    results.postStartStarted.should.equal(false);
    results.postStartStopped.should.equal(false);

    notifier.m_observable.notifyStopped(SystemLifecycleStage.PreBuild);

    results.preBuildStarted.should.equal(true);
    results.preBuildStopped.should.equal(true);

    results.postBuildStarted.should.equal(false);
    results.postBuildStopped.should.equal(false);

    results.preStartStarted.should.equal(false);
    results.preStartStopped.should.equal(false);

    results.postStartStarted.should.equal(false);
    results.postStartStopped.should.equal(false);
}

@("notifier should start postBuild subscriptions")
unittest
{
    auto container = new shared DependencyContainer;
    auto notifier = prepareNotifier(container);
    auto results = container.resolve!(TestLifecycleResults)();

    notifier.notifyBuilt();
    results.preBuildStarted.should.equal(false);
    results.preBuildStopped.should.equal(false);

    results.postBuildStarted.should.equal(true);
    results.postBuildStopped.should.equal(false);

    results.preStartStarted.should.equal(false);
    results.preStartStopped.should.equal(false);

    results.postStartStarted.should.equal(false);
    results.postStartStopped.should.equal(false);

    notifier.m_observable.notifyStopped(SystemLifecycleStage.PostBuild);

    results.preBuildStarted.should.equal(false);
    results.preBuildStopped.should.equal(false);

    results.postBuildStarted.should.equal(true);
    results.postBuildStopped.should.equal(true);

    results.preStartStarted.should.equal(false);
    results.preStartStopped.should.equal(false);

    results.postStartStarted.should.equal(false);
    results.postStartStopped.should.equal(false);
}

@("notifier should start preStart subscriptions")
unittest
{
    auto container = new shared DependencyContainer;
    auto notifier = prepareNotifier(container);
    auto results = container.resolve!(TestLifecycleResults)();

    notifier.notifyStarting();
    results.preBuildStarted.should.equal(false);
    results.preBuildStopped.should.equal(false);

    results.postBuildStarted.should.equal(false);
    results.postBuildStopped.should.equal(false);

    results.preStartStarted.should.equal(true);
    results.preStartStopped.should.equal(false);

    results.postStartStarted.should.equal(false);
    results.postStartStopped.should.equal(false);

    notifier.m_observable.notifyStopped(SystemLifecycleStage.PreStart);

    results.preBuildStarted.should.equal(false);
    results.preBuildStopped.should.equal(false);

    results.postBuildStarted.should.equal(false);
    results.postBuildStopped.should.equal(false);

    results.preStartStarted.should.equal(true);
    results.preStartStopped.should.equal(true);

    results.postStartStarted.should.equal(false);
    results.postStartStopped.should.equal(false);
}

@("notifier should start postStart subscriptions")
unittest
{
    auto container = new shared DependencyContainer;
    auto notifier = prepareNotifier(container);
    auto results = container.resolve!(TestLifecycleResults)();

    notifier.notifyStarted();
    results.preBuildStarted.should.equal(false);
    results.preBuildStopped.should.equal(false);

    results.postBuildStarted.should.equal(false);
    results.postBuildStopped.should.equal(false);

    results.preStartStarted.should.equal(false);
    results.preStartStopped.should.equal(false);

    results.postStartStarted.should.equal(true);
    results.postStartStopped.should.equal(false);

    notifier.m_observable.notifyStopped(SystemLifecycleStage.PostStart);

    results.preBuildStarted.should.equal(false);
    results.preBuildStopped.should.equal(false);

    results.postBuildStarted.should.equal(false);
    results.postBuildStopped.should.equal(false);

    results.preStartStarted.should.equal(false);
    results.preStartStopped.should.equal(false);

    results.postStartStarted.should.equal(true);
    results.postStartStopped.should.equal(true);
}

@("notifier notifyStopping should stop all")
unittest
{
    auto container = new shared DependencyContainer;
    auto notifier = prepareNotifier(container);
    auto results = container.resolve!(TestLifecycleResults)();

    notifier.notifyStopping();

    results.preBuildStarted.should.equal(false);
    results.preBuildStopped.should.equal(true);

    results.postBuildStarted.should.equal(false);
    results.postBuildStopped.should.equal(true);

    results.preStartStarted.should.equal(false);
    results.preStartStopped.should.equal(true);

    results.postStartStarted.should.equal(false);
    results.postStartStopped.should.equal(true);
}
