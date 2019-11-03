module sam.server.core.actormanagment.options;

import core.time;

class ActorLifetimeOptions
{
    Duration collectionDelay = dur!"seconds"(10);
    Duration maxIdle = dur!"seconds"(5);
}