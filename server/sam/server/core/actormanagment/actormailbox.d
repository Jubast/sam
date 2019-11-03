module sam.server.core.actormanagment.actormailbox;

import std.container;
import vibe.core.concurrency;
import vibe.core.sync;
import sam.common.interfaces.actor;
import sam.common.actormessage;
import sam.common.actorresponse;
import sam.server.core.actormanagment.actorinfo;
import sam.server.core.actormanagment.actormanager;

class ActorMailbox
{
    private TaskMutex m_mutex;
    private ActorManager m_manager;

    this(IActor actor, string actorId, ActorInfo info)
    {
        this.m_mutex = new TaskMutex;
        this.m_manager = new ActorManager(actor, actorId, info);
    }

    Future!ActorResponse put(ActorMessage message)
    {
        return async({
            synchronized (m_mutex)
            {
                return m_manager.invoke(message);
            }
        });
    }

    // used internaly for actor lifetime managmanet
    package Future!ManagerResponse managerMessage(ManagerMessage message)
    {
        return async({
            synchronized (m_mutex)
            {
                return m_manager.managerMessage(message);
            }
        });
    }
}

version (unittest)
{
    import std.datetime.stopwatch : StopWatch, AutoStart;
    import core.time : msecs;
    import std.uuid;
    import vibe.core.core;
    import sam.server.actor;
    import sam.server.actorsystem;
    import sam.common.interfaces.actor;    

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
    auto actorSystem = new ActorSystemBuilder() //
    .register!(ITestActor, TestActor) //
    .UseInMemoryActorSystem //
    .build;

    auto client = actorSystem.clientOf;

    auto sw = StopWatch(AutoStart.no);
    sw.start;

    Task[] tasks;
    int[] counts;
    auto test = runTask({                
        for (int i = 0; i < 5; ++i)
        {            
            auto actor = client.actorOf!ITestActor("test");
            tasks ~= runTask({
                counts ~= actor.waitAndGetCount(500);
            });
        }

        foreach(task; tasks) {
            task.join();
        }

        sw.stop;
        exitEventLoop;
    });

    runEventLoop;    

    counts.should.equal([1, 2, 3, 4, 5]);
    auto mesecs = sw.peek.total!"msecs";
    mesecs.should.be.approximately(5*500, 10);    
}

@("diffrenct actors should get processed instantly")
unittest
{
    auto actorSystem = new ActorSystemBuilder() //
    .register!(ITestActor, TestActor) //
    .UseInMemoryActorSystem //
    .build;

    auto client = actorSystem.clientOf;

    auto sw = StopWatch(AutoStart.no);
    sw.start;

    Task[] tasks;
    int[] counts;
    auto test = runTask({        
        for (int i = 0; i < 5; ++i)
        {
            auto actor = client.actorOf!ITestActor(randomUUID.toString);
            tasks ~= runTask({
                counts ~= actor.waitAndGetCount(500);
            });
        }

        foreach(task; tasks) {
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
