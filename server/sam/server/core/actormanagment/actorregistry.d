module sam.server.core.actormanagment.actorregistry;

import poodinis;
import sam.common.interfaces.actor;
import sam.server.core.actormanagment.actorinfo;
import sam.common.exceptions;

class ActorRegistry
{
    private shared DependencyContainer m_dependencies;
    private ActorInfo[TypeInfo] m_actorInfos;

    this(DependencyContainer dependencies)
    {
        this.m_dependencies = cast(shared) dependencies;
    }

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
