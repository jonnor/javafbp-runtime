JavaFBP runtime
----------------

Implementation of the [FBP runtime protocol](http://noflojs.org/documentation/protocol/),
allowing to create [JavaFBP](https://github.com/jpaulm/javafbp) with [Flowhub](http://flowhub.io)
and other compatible clients.

Status
-------
Proof-of-concept. Can be used to create simple programs live with Flowhub and run them.

TODO
------
In roughly prioritized order.

Milestone 0.1: minimally useful

* Fix network excecution blocking main thread, should execute in background
* Add proper commandline arguments for port, library path, runtime registry etc
* Implement redirection of stdout/stderr, for showing in IDE
* Implement introspection of data passing through edges
* Implement support for multiple graphs
* Implement stopping of networks

Later

* Implement support for arrayports
* Implement support for subgraph components
* Implement support for component specific icons
* Implement component:getsource, for showing component .java code in IDE
* Implement component:setsource, for creating components from .java code in IDE
* Implement debug mode, catching exceptions and notifying IDE where they happen
* Implement remote subgraph support, allowing a JavaFBP program/runtime to be used as a component

Building from git
-----------------

    cd runtime
    gradle installApp

Run & Connect to Flowhub
--------------------------
Note: instructions only tested on GNU/Linux

Open [Flowhub](http://app.flowhub.io), log in.
Click "Register runtime" and copy your user UUID.

    export FLOWHUB_USER_ID=MY-USER-UUID-XXX
    ./build/install/runtime/bin/runtime

The runtime should now register itself and listen on a port for UI to connect.

Go back to Flowhub, hit the *refresh icon* next to "Register runtime".

Create a new project, select JavaFBP as the runtime type.
You should now be connected and be able to build JavaFBP programs!



