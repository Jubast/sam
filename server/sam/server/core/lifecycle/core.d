module sam.server.core.lifecycle.core;

interface ILifecycleParticipant
{
    void participate(ILifecycleObservable observable);
}

interface ILifecycleObservable
{
    void subscribe(int stage, void delegate() onStart, void delegate() onStop);
}

package class LifecycleObservable : ILifecycleObservable
{
    private Subscription[] m_subscriptions;

    void subscribe(int stage, void delegate() onStart, void delegate() onStop)
    {
        m_subscriptions ~= new Subscription(stage, onStart, onStop);
    }

    void start(int stage)
    {
        foreach (subscription; m_subscriptions)
        {
            if (subscription.stage == stage)
            {
                subscription.onStart();
            }
        }
    }

    void stop(int stage)
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
    private int m_stage;
    private void delegate() m_onStart;
    private void delegate() m_onStop;

    int stage()
    {
        return m_stage;
    }

    this(int stage, void delegate() onStart, void delegate() onStop)
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