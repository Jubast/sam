module sam.server.core.actorprovider;

import sam.common.enforce;
import sam.common.interfaces.actor;

import sam.server.core.lifetime;
import sam.server.core.introspection;

class ActorProvider
{
	ActivationCollection activationCollection;
	ActorRegistry actorRegistry;

	this(ActivationCollection activationCollection, ActorRegistry actorRegistry)
	{
		this.activationCollection = activationCollection.notNull;
		this.actorRegistry = actorRegistry.notNull;
	}

	Activation activationOf(TypeInfo actorInfo, string actorId)
	{
		return activationCollection.getOrAdd(actorInfo, actorId, actorRegistry.actorInfoOf(actorInfo));
	}
}
