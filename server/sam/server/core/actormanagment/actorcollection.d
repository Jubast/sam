module sam.server.core.actormanagment.actorcollection;

import poodinis;

import vibe.core.core;
import vibe.core.sync;
import vibe.core.log;

import sam.common.enforce;
import sam.common.actormessage;
import sam.server.core.actormanagment.actorinfo;
import sam.server.core.actormanagment.actormailbox;
import sam.server.core.actormanagment.actormanager;

class ActorCollection
{
    private shared DependencyContainer m_container;
    private TaskReadWriteMutex m_mutex;
    private ActorDirectory[TypeInfo] m_actorDirectories;

    this(DependencyContainer container)
    {
        this.m_container = cast(shared) container.notNull;
        m_mutex = new TaskReadWriteMutex;
    }

    ActorMailbox getOrAdd(TypeInfo actorType, string actorId, lazy ActorInfo lazyActorInfo)
    {
        ActorDirectory directory;
        synchronized (m_mutex.reader)
        {
            auto actorDirectoryPtr = actorType in m_actorDirectories;
            if (actorDirectoryPtr !is null)
            {
                directory = *actorDirectoryPtr;
            }
        }

        if (directory !is null)
        {
            return directory.getOrAdd(actorId, lazyActorInfo);
        }

        synchronized (m_mutex.writer)
        {
            auto actorDirectoryPtr = actorType in m_actorDirectories;
            if (actorDirectoryPtr !is null)
            {
                return (*actorDirectoryPtr).getOrAdd(actorId, lazyActorInfo);
            }

            directory = new ActorDirectory(actorType, m_container);
            m_actorDirectories[actorType] = directory;
        }

        return directory.getOrAdd(actorId, lazyActorInfo);
    }

    void removeAll(bool delegate(ActorManagerStatus) predicate)
    {
        Task[] tasks;
        synchronized (m_mutex.reader)
        {
            foreach (directory; m_actorDirectories)
            {
                tasks ~= runTask({ directory.removeAll(predicate); });
            }
        }

        foreach(ref task; tasks) 
        {
            task.join();
        }
    }
}

class ActorDirectory
{
    private TaskReadWriteMutex m_mutex;
    private TypeInfo m_actorType;
    private shared DependencyContainer m_container;
    private ActorMailbox[string] m_actorCollection;

    this(TypeInfo actorType, shared DependencyContainer container)
    {
        this.m_mutex = new TaskReadWriteMutex;
        this.m_actorType = actorType;
        this.m_container = container;
    }

    ActorMailbox getOrAdd(string actorId, lazy ActorInfo lazyActorInfo)
    {
        synchronized (m_mutex.reader)
        {
            auto actorMailboxPtr = actorId in m_actorCollection;
            if (actorMailboxPtr !is null)
            {
                return *actorMailboxPtr;
            }
        }

        synchronized (m_mutex.writer)
        {
            auto actorMailboxPtr = actorId in m_actorCollection;
            if (actorMailboxPtr !is null)
            {
                return *actorMailboxPtr;
            }

            auto actorInfo = lazyActorInfo();
            auto actor = actorInfo.resolver()(m_container, actorId);
            auto mailbox = new ActorMailbox(actor, actorId, actorInfo);
            m_actorCollection[actorId] = mailbox;

            return mailbox;
        }
    }

    void removeAll(bool delegate(ActorManagerStatus) predicate)
    {
        ActorMailbox[string] actorCollection;
        synchronized (m_mutex.reader)
        {
            actorCollection = m_actorCollection.dup;
        }

        foreach (keyValue; actorCollection.byKeyValue)
        {
            auto actorId = keyValue.key;
            auto actorMailbox = keyValue.value;

            auto state = actorMailbox.managerMessage(getManagerState)
                .getResult.variant.get!ActorManagerStatus;

            if (predicate(state))
            {
                synchronized (m_mutex.writer)
                {
                    if ((actorId in m_actorCollection) !is null)
                    {
                        logInfo("Deactivating '" ~ m_actorType.toString ~ ":" ~ actorId ~ "'..");
                        actorMailbox.managerMessage(deactivateActor);
                        m_actorCollection.remove(actorId);
                    }
                }
            }
        }
    }

    private static ManagerMessage deactivateActor()
    {
        return new ManagerMessage("deactivate");
    }

    private static ManagerMessage getManagerState()
    {
        return new ManagerMessage("getManagerState");
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
}

@("getOrAdd should create directory and actor")
unittest
{
    auto dependencies = new shared DependencyContainer();
    auto actorInfo = actorInfo!(ITestActor, TestActor)();

    auto actorCollection = new ActorCollection(cast(DependencyContainer) dependencies);
    auto id = randomUUID.toString;
    auto newActor = actorCollection.getOrAdd(typeid(ITestActor), id, actorInfo);

    actorCollection.m_actorDirectories.length.should.equal(1);
    auto directoryPtr = typeid(ITestActor) in actorCollection.m_actorDirectories;
    assert(directoryPtr !is null, "ActorDirectory was not created!");

    auto directory = *directoryPtr;
    directory.m_actorCollection.length.should.equal(1);
    auto actorPtr = id in directory.m_actorCollection;
    assert(actorPtr !is null, "ActorMailbox was not created!");
}

@("getOrAdd should return existing actor")
unittest
{
    auto dependencies = new shared DependencyContainer();
    auto actorInfo = actorInfo!(ITestActor, TestActor)();

    auto actorCollection = new ActorCollection(cast(DependencyContainer) dependencies);
    auto directory = new ActorDirectory(typeid(ITestActor), dependencies);
    actorCollection.m_actorDirectories[typeid(ITestActor)] = directory;

    auto id = randomUUID.toString;
    auto actor = actorInfo.resolver()(dependencies, id);
    auto mailbox = new ActorMailbox(actor, id, actorInfo);
    directory.m_actorCollection[id] = mailbox;

    auto returnedMailbox = actorCollection.getOrAdd(typeid(ITestActor), id, actorInfo);
    actorCollection.m_actorDirectories.length.should.equal(1);
    (mailbox == returnedMailbox).should.equal(true);
}

@("removeAll with true predicate should remove all")
unittest
{
    auto dependencies = new shared DependencyContainer();
    auto actorInfo = actorInfo!(ITestActor, TestActor)();

    auto actorCollection = new ActorCollection(cast(DependencyContainer) dependencies);
    actorCollection.getOrAdd(typeid(ITestActor), randomUUID.toString, actorInfo);
    actorCollection.getOrAdd(typeid(ITestActor), randomUUID.toString, actorInfo);
    actorCollection.getOrAdd(typeid(ITestActor), randomUUID.toString, actorInfo);

    actorCollection.m_actorDirectories[typeid(ITestActor)].m_actorCollection.length.should.equal(3);
    actorCollection.removeAll(x => true);

    actorCollection.m_actorDirectories[typeid(ITestActor)].m_actorCollection.length.should.equal(0);
}

@("removeAll with false predicate should not remove any")
unittest
{
    auto dependencies = new shared DependencyContainer();
    auto actorInfo = actorInfo!(ITestActor, TestActor)();

    auto actorCollection = new ActorCollection(cast(DependencyContainer) dependencies);
    actorCollection.getOrAdd(typeid(ITestActor), randomUUID.toString, actorInfo);
    actorCollection.getOrAdd(typeid(ITestActor), randomUUID.toString, actorInfo);
    actorCollection.getOrAdd(typeid(ITestActor), randomUUID.toString, actorInfo);

    actorCollection.m_actorDirectories[typeid(ITestActor)].m_actorCollection.length.should.equal(3);
    actorCollection.removeAll(x => false);

    actorCollection.m_actorDirectories[typeid(ITestActor)].m_actorCollection.length.should.equal(3);
}

@("removeAll with predicate should remove")
unittest
{
    auto dependencies = new shared DependencyContainer();
    auto actorInfo = actorInfo!(ITestActor, TestActor)();

    auto actorCollection = new ActorCollection(cast(DependencyContainer) dependencies);
    auto knownId = randomUUID.toString;
    actorCollection.getOrAdd(typeid(ITestActor), knownId, actorInfo);
    actorCollection.getOrAdd(typeid(ITestActor), randomUUID.toString, actorInfo);
    actorCollection.getOrAdd(typeid(ITestActor), randomUUID.toString, actorInfo);

    actorCollection.m_actorDirectories[typeid(ITestActor)].m_actorCollection.length.should.equal(3);
    actorCollection.removeAll(x => x.actorId == knownId);

    actorCollection.m_actorDirectories[typeid(ITestActor)].m_actorCollection.length.should.equal(2);
}