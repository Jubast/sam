module sam.server.core.scheduler.actortaskscheduler;

import std.container.dlist;

import vibe.core.core;
import vibe.core.task;
import vibe.core.sync;

import sam.common.interfaces.actor;
import sam.common.actormessage;
import sam.common.actorresponse;

import sam.server.core.introspection.actorinfo;
import sam.server.core.scheduler.actorinvoker;
import sam.server.core.scheduler.asyncresult;

class ActorTaskScheduler
{
    private TaskMutex m_mutex;
    private ActorInvoker m_invoker;
    private DList!IAsyncResult m_queue;
    private shared(ManualEvent) m_event = createSharedManualEvent();
    private Task m_executingTask;

    string actorId()
    {
        return m_invoker.actorId;
    }

    TypeInfo actorType()
    {
        return m_invoker.actorInfo.actorType;
    }

    this(IActor actor, string actorId, ActorInfo info)
    {
        this.m_mutex = new TaskMutex;
        this.m_invoker = new ActorInvoker(actor, actorId, info);
        this.m_executingTask = runActorEventLoop();
    }

    AsyncResult!ActorResponse put(ActorMessage message)
    {
        auto item = new AsyncResult!ActorResponse({
            return m_invoker.invoke(message);
        });

        synchronized (m_mutex)
        {
            m_queue.insertBack(item);
        }
        m_event.emit();
        return item;
    }

    AsyncResult!ManagerResponse managerPut(ManagerMessage message)
    {
        auto item = new AsyncResult!ManagerResponse({
            return m_invoker.managerInvoke(message);
        });

        synchronized (m_mutex)
        {
            m_queue.insertBack(item);
        }
        m_event.emit();
        return item;
    }

    private Task runActorEventLoop()
    {
        auto actorEventLoopTask = runTask({
            auto emitCount = m_event.emitCount;
            while (true)
            {
                m_event.wait(emitCount);
                emitCount++;

                IAsyncResult item;
                synchronized (m_mutex)
                {
                    item = m_queue.front();
                    m_queue.removeFront();                    
                }

                item.execute();
            }
        });
        return actorEventLoopTask;
    }
}

version (unittest)
{
    import std.datetime.stopwatch : StopWatch, AutoStart;
    import core.time : msecs;
    import std.uuid;

    import sam.server.actor;
    import sam.common.interfaces.actor;
    import sam.common.actormessage;

    import fluent.asserts;

    interface ITestActor : IActor
    {
        int waitAndGetCount(int number);
    }

    class TestActor : Actor, ITestActor
    {
        int count;

        int waitAndGetCount(int number)
        {
            count++;
            sleep(number.msecs);
            return count;
        }
    }
}

@("requests should get processed in order")
unittest
{
    auto actorInfo = actorInfo!(ITestActor, TestActor)();
    auto actor = new TestActor;

    auto actorTaskScheduler = new ActorTaskScheduler(actor, "test", actorInfo);
    auto actorMessage = new ActorMessage(actorInfo.actorType, "test", "waitAndGetCount", 500);

    auto activateTask = runTask({ actorTaskScheduler.managerPut(new ManagerMessage("activate")).getResult; });

    auto sw = StopWatch(AutoStart.yes);

    Task[] tasks;
    int[] counts;

    auto test = runTask({
        activateTask.join();
        for (int i = 0; i < 5; ++i)
        {
            tasks ~= runTask({                
                auto actorResult = actorTaskScheduler.put(actorMessage).getResult;
                counts ~= actorResult.value.get!int;
            });
        }

        foreach (task; tasks)
        {
            task.join();
        }

        sw.stop;
        exitEventLoop;
    });

    runEventLoop;

    counts.should.equal([1, 2, 3, 4, 5]);
    auto mesecs = sw.peek.total!"msecs";
    mesecs.should.be.approximately(5 * 500, 10);
}

@("diffrenct actors should get processed instantly")
unittest
{
    auto actorInfo = actorInfo!(ITestActor, TestActor)();    

    auto sw = StopWatch(AutoStart.yes);

    Task[] tasks;
    int[] counts;
    auto test = runTask({
        for (int i = 0; i < 5; ++i)
        {
            auto actor = new TestActor;
            auto actorId = randomUUID.toString;
            auto actorTaskScheduler = new ActorTaskScheduler(actor, actorId, actorInfo);
            actorTaskScheduler.managerPut(new ManagerMessage("activate")).getResult;

            auto actorMessage = new ActorMessage(actorInfo.actorType, actorId, "waitAndGetCount", 500);

            tasks ~= runTask({
                
                auto actorResult = actorTaskScheduler.put(actorMessage).getResult;
                counts ~= actorResult.value.get!int;
            });
        }

        foreach (task; tasks)
        {
            task.join();
        }

        sw.stop;
        exitEventLoop;
    });

    runEventLoop;

    counts.should.equal([1, 1, 1, 1, 1]);
    auto mesecs = sw.peek.total!"msecs";
    mesecs.should.be.approximately(500, 50);
}
