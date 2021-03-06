module sam.server.core.actormanagment.actorprovider;

import sam.common.enforce;
import sam.common.interfaces.actor;
import sam.server.core.actormanagment.actormailbox;
import sam.server.core.actormanagment.actorcollection;
import sam.server.core.actormanagment.actorregistry;

class ActorProvider
{
	ActorCollection actorCollection;
	ActorRegistry actorRegistry;

	this(ActorCollection actorCollection, ActorRegistry actorRegistry)
	{
		this.actorCollection = actorCollection.notNull;
		this.actorRegistry = actorRegistry.notNull;
	}

	ActorMailbox mailboxOf(TypeInfo actorInfo, string actorId)
	{
		return actorCollection.getOrAdd(actorInfo, actorId, actorRegistry.actorInfoOf(actorInfo));
	}
}
