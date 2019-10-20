module sam.server.core.actormanagment.actorcollection;

import poodinis;
import core.sync.rwmutex;

import std.concurrency : Generator, yield;

import sam.common.enforce;
import sam.common.actormessage;
import sam.server.core.actormanagment.actorinfo;
import sam.server.core.actormanagment.actormailbox;

class ActorCollection
{
    private shared DependencyContainer container;
    private ReadWriteMutex mutex;
    private ActorMailbox[string][TypeInfo] internalCollection;

    this(DependencyContainer container)
    {
        this.container = cast(shared) container.notNull;
        mutex = new ReadWriteMutex;
    }

    ActorMailbox getOrAdd(TypeInfo actorType, string actorId, lazy ActorInfo lazyActorInfo)
    {
        synchronized (mutex.reader)
        {
            auto actorDirectoryPtr = actorType in internalCollection;
            if (actorDirectoryPtr !is null)
            {
                auto actorManagerPtr = actorId in *actorDirectoryPtr;
                if (actorManagerPtr !is null)
                {
                    return *actorManagerPtr;
                }
            }
        }

        synchronized(mutex.writer)
        {
            auto actorInfo = lazyActorInfo();
            auto actor = actorInfo.resolver()(container, actorId);
            auto mailbox = new ActorMailbox(actor, actorId, actorInfo);
            internalCollection[actorType][actorId] = mailbox;

            return mailbox;
        }
    }

    void removeIf(bool function(ActorMailbox) func)
    {
        synchronized (mutex.writer)
        {
            auto ic = internalCollection.dup;
            foreach (type; ic.byKey)
            {                
                auto directory = ic[type].dup;
                foreach (id; directory.byKey)
                {
                    auto mailbox = directory[id];
                    if(func(mailbox))
                    {
                        internalCollection[type].remove(id);
                    }
                }
            }
        }
    }    
}
