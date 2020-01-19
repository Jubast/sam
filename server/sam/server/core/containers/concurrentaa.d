module sam.server.core.containers.concurrentaa;

import std.typecons;

import vibe.core.core;
import vibe.core.sync;
import vibe.core.log;

class TaskConcurrentAA(TKey, TValue)
{
    private TaskReadWriteMutex m_mutex;
    private TValue[TKey] m_aa;

    this()
    {
        this.m_mutex = new TaskReadWriteMutex();
    }

    TValue getOrAdd(TKey key, Tuple!(TValue, Task) delegate() lazyValue)
    {
        synchronized (m_mutex.reader)
        {
            auto valuePtr = key in m_aa;
            if (valuePtr !is null)
            {
                return *valuePtr;
            }
        }

        Tuple!(TValue, Task) value;
        synchronized (m_mutex.writer)
        {
            auto valuePtr = key in m_aa;
            if (valuePtr !is null)
            {
                return *valuePtr;
            }
            
            value = lazyValue();
            m_aa[key] = value[0];            
        }

        // wait for the task to complete
        value[1].join();
        return value[0];
    }

    bool remove(TKey key)
    {
        synchronized (m_mutex.writer)
        {
            return m_aa.remove(key);
        }
    }

    size_t length()
    {
        synchronized (m_mutex.reader)
        {
            return m_aa.length;
        }
    }

    TValue* opBinary(string op)(TKey key)
    {
        synchronized (m_mutex.reader)
        {
            static if (op == "in")
            {
                return key in m_aa;
            }
            else
                static assert(0, "Operator " ~ op ~ " not implemented");
        }
    }

    TValue* opBinaryRight(string op)(TKey key)
    {
        synchronized (m_mutex.reader)
        {
            static if (op == "in")
            {
                return key in m_aa;
            }
            else
                static assert(0, "Operator " ~ op ~ " not implemented");
        }
    }

    TValue[TKey] dupUnsafe()
    {
        synchronized (m_mutex.reader)
        {
            return m_aa.dup;
        }
    }
}
