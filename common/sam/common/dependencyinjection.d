module sam.common.dependencyinjection;

import po = poodinis;
import std.conv;

// Abstraction for the DI if i ever change the DI provider. (because poodins DependencyContainer is synchronized)

enum RegisterOption
{
    singleton,
    newInstance,
    existing
}

enum ResolveOption
{
    optional,
    required
}

class ContainerBuilder
{
    private shared po.DependencyContainer m_container;

    this()
    {
        m_container = new shared po.DependencyContainer();
    }

    void register(TIService, TService)(RegisterOption option, TService service = null)
    {
        final switch (option)
        {
        case RegisterOption.singleton:
            auto reg = m_container.register!(TIService,
                    TService)(po.RegistrationOption.doNotAddConcreteTypeRegistration);
            po.singleInstance(reg);
            break;
        case RegisterOption.newInstance:
            auto reg = m_container.register!(TIService,
                    TService)(po.RegistrationOption.doNotAddConcreteTypeRegistration);
            po.newInstance(reg);
            break;
        case RegisterOption.existing:
            auto reg = m_container.register!(TIService,
                    TService)(po.RegistrationOption.doNotAddConcreteTypeRegistration);
            po.existingInstance(reg, service);
            break;
        }
    }

    void register(TIService, TService)()
    {
        register!(TIService, TService)(RegisterOption.newInstance);
    }

    void register(TService)()
    {
        register!(TService, TService)(RegisterOption.newInstance);
    }

    void registerSingleton(TIService, TService)()
    {
        register!(TIService, TService)(RegisterOption.singleton);
    }

    void registerSingleton(TService)()
    {
        register!(TService, TService)(RegisterOption.singleton);
    }

    void registerExisting(TIService, TService)(TService delegate(Container) factory)
    {
        auto container = new Container();
        container.init(m_container);

        auto service = factory(container);
        register!(TIService, TService)(RegisterOption.existing, service);
    }

    void registerExisting(TIService, TService)(TService service)
    {
        register!(TIService, TService)(RegisterOption.existing, service);
    }

    void registerExisting(TService)(TService service)
    {
        register!(TService, TService)(RegisterOption.existing, service);
    }

    Container build()
    {
        auto container = new Container();
        container.init(m_container);
        return container;
    }
}

class Container
{
    private shared po.DependencyContainer m_container;

    /** This public empty constructor exsists because of template errors in poodins ConstructorInjectingInstanceFactory when self registering.
     * For Container creation $(D ContainerBuilder.build()) should be used!.
     * To initialize this object use $(D Container.init')
     */
    this()
    {
        m_container = new shared po.DependencyContainer;
    }

    void init(shared(po.DependencyContainer) container)
    {
        m_container = container;
        auto reg = m_container.register!(Container)();
        po.existingInstance(reg, this);
    }

    TService resolve(TService)(ResolveOption option)
    {
        final switch (option)
        {
        case ResolveOption.optional:
            return m_container.resolve!(TService)(po.ResolveOption.noResolveException);
        case ResolveOption.required:
            return m_container.resolve!(TService)(po.ResolveOption.none);
        }
    }

    TService resolve(TService)()
    {
        return resolve!(TService)(ResolveOption.optional);
    }

    TService[] resolveAll(TService)()
    {
        return m_container.resolveAll!(TService)(po.ResolveOption.noResolveException);
    }
}

version (unittest)
{
    import fluent.asserts;
    import std.stdio;
    import std.uuid;

    class TestDependency
    {
        string data;

        this()
        {
            data = randomUUID.toString;
        }
    }

    interface ITestInterface {}
    class Dep1 : ITestInterface {}
    class Dep2 : ITestInterface {}
    class Dep3 : ITestInterface {}
}

@("register should register new instance")
unittest
{
    auto builder = new ContainerBuilder;
    builder.register!TestDependency;

    auto container = builder.build();
    auto dep = container.resolve!TestDependency;
    auto dep2 = container.resolve!TestDependency;

    dep.data.should.not.equal(dep2.data);
}

@("registerSingleton should register singleton")
unittest
{
    auto builder = new ContainerBuilder;
    builder.registerSingleton!TestDependency;

    auto container = builder.build();
    auto dep = container.resolve!TestDependency;
    auto dep2 = container.resolve!TestDependency;

    dep.data.should.equal(dep2.data);
}

@("registerExisting should return existing")
unittest
{
    auto builder = new ContainerBuilder;
    auto dep = new TestDependency;
    builder.registerExisting(dep);

    auto container = builder.build();
    auto dep2 = container.resolve!TestDependency;

    dep.data.should.equal(dep2.data);
}

@("resolveAll should return all")
unittest
{
    auto builder = new ContainerBuilder;
    builder.registerSingleton!(ITestInterface, Dep1)();
    builder.registerSingleton!(ITestInterface, Dep2)();
    builder.registerSingleton!(ITestInterface, Dep3)();

    auto container = builder.build();
    auto deps = container.resolveAll!ITestInterface;
    deps.length.should.equal(3);
}
