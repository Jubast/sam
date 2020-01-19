module sam.server.core.introspection.actoractivator;

import std.traits;
import sam.common.interfaces.actor;
import sam.common.udas;
import sam.common.dependencyinjection;

class ActorActivator(TActor)
{
    Container m_container;

    this(Container container)
    {
        m_container = container;
    }

    TActor getInstance(string id)
    {
        TActor actor;
        static if (__traits(compiles, __traits(getOverloads, TActor, `__ctor`)))
        {
            foreach (ctor; __traits(getOverloads, TActor, `__ctor`))
            {
                alias Params = Parameters!ctor;
                Params args;

                static foreach (i, Param; Params)
                {
                    args[i] = m_container.resolve!Param;
                }

                actor = new TActor(args);                
            }
        }
        
        if(actor is null)
        {
            actor = cast(TActor)typeid(TActor).create();
        }

        static if(hasMember!(TActor, "id") && hasUDA!(mixin("TActor.id"), actorId))
        {
            actor.id = id;
        }

        return actor;
    }
}

version(unittest)
{
    import fluent.asserts;
    import std.uuid;

    class EmptyActor
    {    }

    class ActorIdActor
    {
        @actorId string id;
    }

    class Dependency1
    {        
    }

    class Dependency2
    {        
    }

    class DependenciesActor
    {
        Dependency1 dependency1;
        Dependency2 dependency2;

        this(Dependency1 dependency1, Dependency2 dependency2)
        {
            this.dependency1 = dependency1;
            this.dependency2 = dependency2;
        }
    }
}

@("should create a new actor")
unittest
{
    auto dependencies = new ContainerBuilder();
    auto activator = new ActorActivator!EmptyActor(dependencies.build());
    auto instance = activator.getInstance(null);

    instance.should.not.beNull;
}

@("should create a new actor and insert id")
unittest
{
    auto dependencies = new ContainerBuilder();
    auto activator = new ActorActivator!ActorIdActor(dependencies.build());
    auto id = randomUUID.toString;
    auto instance = activator.getInstance(id);
    
    instance.should.not.beNull;
    instance.id.should.equal(id);
}

@("should create a new actor with dependencies")
unittest
{
    auto dependencies = new ContainerBuilder();
    dependencies.register!Dependency1;
    dependencies.register!Dependency2;

    auto activator = new ActorActivator!DependenciesActor(dependencies.build());    
    auto instance = activator.getInstance(null);
    
    instance.dependency1.should.not.beNull;
    instance.dependency2.should.not.beNull;
}