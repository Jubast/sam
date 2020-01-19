module sam.common.interfaces.actorsystem;

import sam.common.dependencyinjection;

interface IActorSystem
{
    Container container();
    void start();
    void stop();    
}