For the latest information about ZooKeeper, please visit our website at:

   http://zookeeper.apache.org/

and our wiki, at:

   https://cwiki.apache.org/confluence/display/ZOOKEEPER

Full documentation for this release can also be found in docs/index.html

---------------------------
Packaging/release artifacts

The release artifact contains the following jar file at the toplevel:

zookeeper-<version>.jar         - legacy jar file which contains all classes
                                  and source files. Prior to version 3.3.0 this
                                  was the only jar file available. It has the 
                                  benefit of having the source included (for
                                  debugging purposes) however is also larger as
                                  a result

The release artifact contains the following jar files in "dist-maven" directory:

zookeeper-<version>.jar         - bin (binary) jar - contains only class (*.class) files
zookeeper-<version>-sources.jar - contains only src (*.java) files
zookeeper-<version>-javadoc.jar - contains only javadoc files

These bin/src/javadoc jars were added specifically to support Maven/Ivy which have 
the ability to pull these down automatically as part of your build process. 
The content of the legacy jar and the bin+sources jar are the same.

As of version 3.3.0 bin/sources/javadoc jars contained in dist-maven directory
are deployed to the Apache Maven repository after the release has been accepted
by Apache:
  http://people.apache.org/repo/m2-ibiblio-rsync-repository/
Patch Upgrade - Wed Nov 15 10:28:10 UTC 2017
Patch Upgrade - Sat Nov 25 14:55:59 UTC 2017
Patch Upgrade - Sat Nov 25 19:14:22 UTC 2017
Patch Upgrade - Mon Nov 27 12:55:20 UTC 2017
Patch Upgrade - Wed Nov 29 17:55:14 UTC 2017
Patch Upgrade - Wed Dec  6 11:07:01 UTC 2017
Patch Upgrade - Wed Dec  6 18:35:33 UTC 2017
Patch Upgrade - Sun Dec 10 04:25:25 UTC 2017
Patch Upgrade - Sun Dec 10 10:13:12 UTC 2017
Patch Upgrade - Sat Dec 16 14:51:50 UTC 2017
Patch Upgrade - Thu Jan 11 11:14:32 UTC 2018
