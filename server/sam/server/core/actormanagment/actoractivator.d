module sam.server.core.actormanagment.actoractivator;

import poodinis;
import std.traits;
import sam.common.interfaces.actor;
import sam.common.udas;

class ActorActivator(TActor)
{
    shared DependencyContainer m_container;

    this(DependencyContainer container)
    {
        m_container = cast(shared) container;
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

                static foreach (i, Param; Params[0 .. $])
                {
                    args[i] = container.resolve!Param;
                }

                actor = new TActor(args);                
            }
        }
        
        if(actor is null)
        {
            actor = cast(TActor)typeid(TActor).create();
        }

        static if(hasMember!(TActor, "id") && hasUDA!(mixin("TActor.id"), ActorId))
        {
            actor.id = id;
        }

        return actor;
    }
}
