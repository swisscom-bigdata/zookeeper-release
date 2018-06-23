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
Patch Upgrade - Wed May  9 12:35:43 UTC 2018
Patch Upgrade - Thu May 17 09:05:17 UTC 2018
Patch Upgrade - Thu May 24 06:32:41 UTC 2018
Patch Upgrade - Thu May 24 11:29:52 UTC 2018
Patch Upgrade - Sun May 27 08:32:49 UTC 2018
Patch Upgrade - Sun May 27 12:41:17 UTC 2018
Patch Upgrade - Mon Jun  4 12:57:56 UTC 2018
Patch Upgrade - Wed Jun  6 07:54:15 UTC 2018
Patch Upgrade - Thu Jun  7 05:55:07 UTC 2018
Patch Upgrade - Thu Jun  7 06:02:48 UTC 2018
Patch Upgrade - Sat Jun  9 11:26:20 UTC 2018
Patch Upgrade - Sat Jun  9 14:59:52 UTC 2018
Patch Upgrade - Tue Jun 12 10:08:34 UTC 2018
Patch Upgrade - Wed Jun 13 11:23:58 UTC 2018
Patch Upgrade - Thu Jun 14 07:55:40 UTC 2018
Patch Upgrade - Sat Jun 16 14:27:53 UTC 2018
Patch Upgrade - Wed Jun 20 09:57:04 UTC 2018
Patch Upgrade - Sat Jun 23 18:59:38 UTC 2018
