module sam.server.core.scheduler.asyncresult;

import vibe.core.concurrency;
import vibe.core.sync;

class AsyncResult(TResult) : IAsyncResult
{
    private TResult delegate() m_del;
    private Future!TResult m_future;
    private shared(ManualEvent) m_event = createSharedManualEvent();
    private int emitCount;

    this(TResult delegate() del)
    {
        this.m_del = del;
        this.emitCount = m_event.emitCount;
    }

    TResult getResult()
    {
        m_event.wait(emitCount);
        return m_future.getResult();
    }

    override void execute()
    {
        try{
            m_future = async(m_del);                    
            m_future.getResult;
        }
        catch(Exception)
        {
            // ignore. we only care that the task was executed.
        }

        m_event.emit();        
    }
}

package interface IAsyncResult
{
    void execute();
}

version (unittest)
{
    import fluent.asserts;
    import vibe.core.core;
    import std.datetime.stopwatch : StopWatch, AutoStart;
    import core.time : msecs;
}

@("AsyncResult should wait for task to get started")
unittest
{
    auto value = "Hello World!";
    auto result = new AsyncResult!string(() => value);

    auto sleepTime = 10;
    auto sw = StopWatch(AutoStart.yes);

    string resultValue;
    runTask({ resultValue = result.getResult; sw.stop; exitEventLoop; });
    runTask({ sleep(sleepTime.msecs); result.execute(); });
    runEventLoop;
    
    auto mesecs = sw.peek.total!"msecs";
    mesecs.should.be.approximately(sleepTime, 5);
}