module sam.server.core.actormanagment.actorinfo;

import poodinis;
import std.traits;
import std.variant;
import sam.common.interfaces.actor;
import sam.common.enforce;
import sam.common.actormessage;
import sam.common.actorresponse;
import sam.server.core.actormanagment.actoractivator;

alias ResolverFunc = IActor function(shared DependencyContainer contianer, string id);

class ActorInfo
{
    private TypeInfo m_actorType;
    private ResolverFunc m_resolver;
    private MethodInfo[] m_methodInfos;

    TypeInfo actorType()
    {
        return m_actorType;
    }

    ResolverFunc resolver()
    {
        return m_resolver;
    }

    MethodInfo[] methodInfos()
    {
        return m_methodInfos;
    }

    this(TypeInfo actorType, ResolverFunc resolver, MethodInfo[] methodInfos)
    {
        this.m_actorType = actorType;
        this.m_resolver = resolver;
        this.m_methodInfos = methodInfos;
    }
}

ActorInfo actorInfo(TIActor : IActor, TActor : IActor)()
        if (is(TIActor == interface) && !__traits(isTemplate, TIActor)
        && is(TActor == class) && !__traits(isTemplate, TActor))
{
    static IActor resolve(shared DependencyContainer container, string id)
    {
        return new ActorActivator!TActor(cast(DependencyContainer) container).getInstance(id);        
    }

    return new ActorInfo(typeid(TIActor), &resolve, methodInfos!TIActor);
}

alias InvokeFunc = ActorResponse function(IActor, Variant[]);

class MethodInfo
{
    string name;
    TypeInfo[] args;
    InvokeFunc invoke;

    this(string name, TypeInfo[] args, InvokeFunc invoke)
    {
        this.name = name.notNull;
        this.args = args;
        this.invoke = invoke.notNull;
    }
}

MethodInfo[] methodInfos(TIActor : IActor)()
        if (is(TIActor == interface) && !__traits(isTemplate, TIActor))
{
    MethodInfo[] methodInfos;

    static foreach (member; __traits(allMembers, TIActor))
    {
        static foreach (index, overload; __traits(getOverloads, TIActor, member))
        {
            static if (__traits(isVirtualMethod, overload))
            {
                {
                    alias Params = Parameters!overload;                    

                    TypeInfo[] types;
                    foreach (Param; Params)
                    {
                        types ~= typeid(Param);
                    }

                    auto func = &invokeMethod!(member, overload, TIActor);
                    methodInfos ~= new MethodInfo(member, types, func);
                }
            }
        }
    }

    return methodInfos;
}

ActorResponse invokeMethod(string methodName, alias overload, TIActor)(IActor obj, Variant[] vArgs)
{
    alias Params = Parameters!overload;       

    Params args;
    foreach (i, Param; Params)
    {
        args[i] = vArgs[i].get!Param;
    }

    auto actor = cast(TIActor) obj;
    
    static if (is(ReturnType!overload == void))
    {
        mixin("actor." ~ methodName)(args);
        Variant v;
        return new ActorResponse(v);
    }
    else
    {        
        Variant v;
        v = mixin("actor." ~ methodName)(args);
        return new ActorResponse(v);
    }    
}
