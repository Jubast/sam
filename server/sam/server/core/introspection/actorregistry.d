module sam.server.core.introspection.actorregistry;

import sam.common.interfaces.actor;
import sam.common.exceptions;

import sam.server.core.introspection.actorinfo;

class ActorRegistry
{
    private ActorInfo[TypeInfo] m_actorInfos;

    void register(TIActor : IActor, TActor : IActor)()
            if (is(TIActor == interface) && !__traits(isTemplate, TIActor)
                && is(TActor == class) && !__traits(isTemplate, TActor))
    {
        auto actorType = typeid(TIActor);
        if ((actorType in m_actorInfos) == null)
        {
            m_actorInfos[actorType] = actorInfo!(TIActor, TActor);
        }
        else
        {
            throw new InvalidOperationException(
                    "Actor interface of type '" ~ TIActor.stringof
                    ~ "' is already added to ActorResovler");
        }
    }

    auto registerdTypes()
    {
        return m_actorInfos.byKey;
    }

    ActorInfo actorInfoOf(TypeInfo actorType)
    {
        auto p = actorType in m_actorInfos;
        if (p !is null)
        {
            return *p;
        }

        throw new InvalidOperationException(
                "Actor interface of type '" ~ actorType.stringof
                ~ "' doesn't exist in ActorResovler");
    }
}
