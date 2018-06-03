/**
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.apache.zookeeper;

import static org.junit.Assert.*;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.PrintStream;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;

import org.apache.zookeeper.AsyncCallback.StringCallback;
import org.apache.zookeeper.AsyncCallback.VoidCallback;
import org.apache.zookeeper.KeeperException.Code;
import org.apache.zookeeper.ZooDefs.Ids;
import org.apache.zookeeper.test.ClientBase;
import org.junit.Assert;
import org.junit.Test;


/**
 * 
 * Testing Zookeeper public methods
 *
 */
public class ZooKeeperTest extends ClientBase {

    @Test
    public void testDeleteRecursive() throws IOException, InterruptedException,
            KeeperException {
        final ZooKeeper zk = createClient();
        // making sure setdata works on /
        zk.setData("/", "some".getBytes(), -1);
        zk.create("/a", "some".getBytes(), Ids.OPEN_ACL_UNSAFE,
                CreateMode.PERSISTENT);

        zk.create("/a/b", "some".getBytes(), Ids.OPEN_ACL_UNSAFE,
                CreateMode.PERSISTENT);

        zk.create("/a/b/v", "some".getBytes(), Ids.OPEN_ACL_UNSAFE,
                CreateMode.PERSISTENT);

        zk.create("/a/b/v/1", "some".getBytes(), Ids.OPEN_ACL_UNSAFE,
                CreateMode.PERSISTENT);

        zk.create("/a/c", "some".getBytes(), Ids.OPEN_ACL_UNSAFE,
                CreateMode.PERSISTENT);

        zk.create("/a/c/v", "some".getBytes(), Ids.OPEN_ACL_UNSAFE,
                CreateMode.PERSISTENT);

        List<String> children = zk.getChildren("/a", false);

        Assert.assertEquals("2 children - b & c should be present ", children
                .size(), 2);
        Assert.assertTrue(children.contains("b"));
        Assert.assertTrue(children.contains("c"));

        ZKUtil.deleteRecursive(zk, "/a");
        Assert.assertNull(zk.exists("/a", null));
    }

    @Test
    public void testDeleteRecursiveAsync() throws IOException,
            InterruptedException, KeeperException {
        final ZooKeeper zk = createClient();
        // making sure setdata works on /
        zk.setData("/", "some".getBytes(), -1);
        zk.create("/a", "some".getBytes(), Ids.OPEN_ACL_UNSAFE,
                CreateMode.PERSISTENT);

        zk.create("/a/b", "some".getBytes(), Ids.OPEN_ACL_UNSAFE,
                CreateMode.PERSISTENT);

        zk.create("/a/b/v", "some".getBytes(), Ids.OPEN_ACL_UNSAFE,
                CreateMode.PERSISTENT);

        zk.create("/a/b/v/1", "some".getBytes(), Ids.OPEN_ACL_UNSAFE,
                CreateMode.PERSISTENT);

        zk.create("/a/c", "some".getBytes(), Ids.OPEN_ACL_UNSAFE,
                CreateMode.PERSISTENT);

        zk.create("/a/c/v", "some".getBytes(), Ids.OPEN_ACL_UNSAFE,
                CreateMode.PERSISTENT);

        for (int i = 0; i < 50; ++i) {
            zk.create("/a/c/" + i, "some".getBytes(), Ids.OPEN_ACL_UNSAFE,
                    CreateMode.PERSISTENT);
        }
        List<String> children = zk.getChildren("/a", false);

        Assert.assertEquals("2 children - b & c should be present ", children
                .size(), 2);
        Assert.assertTrue(children.contains("b"));
        Assert.assertTrue(children.contains("c"));

        VoidCallback cb = new VoidCallback() {

            @Override
            public void processResult(int rc, String path, Object ctx) {
                synchronized (ctx) {
                    ((AtomicInteger) ctx).set(4);
                    ctx.notify();
                }
            }

        };
        final AtomicInteger ctx = new AtomicInteger(3);
        ZKUtil.deleteRecursive(zk, "/a", cb, ctx);
        synchronized (ctx) {
            ctx.wait();
        }
        Assert.assertEquals(4, ((AtomicInteger) ctx).get());
    }
    
    @Test
    public void testStatWhenPathDoesNotExist() throws IOException,
    		InterruptedException {
    	final ZooKeeper zk = createClient();
    	ZooKeeperMain main = new ZooKeeperMain(zk);
    	String cmdstring = "stat /invalidPath";
    	main.cl.parseCommand(cmdstring);
    	try {
    		main.processZKCmd(main.cl);
    		Assert.fail("As Node does not exist, command should fail by throwing No Node Exception.");
    	} catch (KeeperException e) {
    		Assert.assertEquals("KeeperErrorCode = NoNode for /invalidPath", e.getMessage());
    	}
    }

    @Test
    public void testParseWithExtraSpaces() throws Exception {
        final ZooKeeper zk = createClient();
        ZooKeeperMain zkMain = new ZooKeeperMain(zk);
        String cmdstring = "      ls       /  ";
        zkMain.cl.parseCommand(cmdstring);
        Assert.assertEquals("Spaces also considered as characters", zkMain.cl.getNumArguments(), 2);
        Assert.assertEquals("ls is not taken as first argument", zkMain.cl.getCmdArgument(0), "ls");
        Assert.assertEquals("/ is not taken as second argument", zkMain.cl.getCmdArgument(1), "/");
    }

    @Test
    public void testCheckInvalidAcls() throws Exception {
         final ZooKeeper zk = createClient();
            ZooKeeperMain zkMain = new ZooKeeperMain(zk);
            String cmdstring = "create -s -e /node data ip:scheme:gggsd"; //invalid acl's
            try{
                 zkMain.executeLine(cmdstring);
            }catch(KeeperException.InvalidACLException e){
                fail("For Invalid ACls should not throw exception");
            }
    }

    @Test
    public void testDeleteWithInvalidVersionNo() throws Exception {
         final ZooKeeper zk = createClient();
            ZooKeeperMain zkMain = new ZooKeeperMain(zk);
            String cmdstring = "create -s -e /node1 data "; 
            String cmdstring1 = "delete /node1 2";//invalid dataversion no
                 zkMain.executeLine(cmdstring);
           try{
               zkMain.executeLine(cmdstring1);
                     
            }catch(KeeperException.BadVersionException e){
                fail("For Invalid dataversion number should not throw exception");
            }
    }

    @Test
    public void testCliCommandsNotEchoingUsage() throws Exception {
            // setup redirect out/err streams to get System.in/err, use this judiciously!
           final PrintStream systemErr = System.err; // get current err
           final ByteArrayOutputStream errContent = new ByteArrayOutputStream();
           System.setErr(new PrintStream(errContent));
           final ZooKeeper zk = createClient();
           ZooKeeperMain zkMain = new ZooKeeperMain(zk);
           String cmd1 = "printwatches";
           zkMain.executeLine(cmd1);
           String cmd2 = "history";
           zkMain.executeLine(cmd2);
           String cmd3 = "redo";
           zkMain.executeLine(cmd3);
           // revert redirect of out/err streams - important step!
           System.setErr(systemErr);
           if (errContent.toString().contains("ZooKeeper -server host:port cmd args")) {
                fail("CLI commands (history, redo, connect, printwatches) display usage info!");
            }
    }


    private List<String> createAndLsRecusively(List<String> expected, String startNode) 
    		throws IOException, InterruptedException, KeeperException {
    	final ZooKeeper zk = createClient();
    	for (String s : expected) {
            zk.create(s, s.getBytes(), Ids.OPEN_ACL_UNSAFE,
                    CreateMode.PERSISTENT);    		
    	}
        final List<String> actual = new ArrayList<String>();
        ZKUtil.visitSubTreeDFS(zk, startNode, false, new StringCallback() {
            @Override
            public void processResult(int rc, String path, Object ctx, String name) {
                System.out.println(path);
                actual.add(path);
            }
        });
        return actual;
    }

    @Test
    public void testLsrCommand() throws Exception {
    	List<String> expected = Arrays.asList("/a", "/a/b", "/a/c", "/a/f", "/a/b/d", "/a/c/e");
        Assert.assertEquals("test ls -R /a", expected, createAndLsRecusively(expected, "/a"));
    }

    
    @Test
    public void testLsrRootCommand() throws Exception {
        List<String> expected = Arrays.asList("/", "/zookeeper", "/zookeeper/quota");
        List<String> empty = new ArrayList<String>();
        Assert.assertEquals("test ls -R /", expected, createAndLsRecusively(empty, "/"));
    }

    @Test
    public void testLsrLeafCommand() throws Exception {
    	List<String> create = Arrays.asList("/b", "/b/c");
    	List<String> expected = Arrays.asList("/b/c");
        Assert.assertEquals("ls -R /b/c", expected, createAndLsRecusively(create, "/b/c"));
    } 


    @Test
    public void testLsrNonexistantZnodeCommand() throws Exception {
    	List<String> create = Arrays.asList("/b", "/b/c");
        try {
            createAndLsRecusively(create, "/b/c/d");
            Assert.fail("Path doesn't exists so, command should fail.");
        } catch (Exception e) {
            //Assert.assertEquals(KeeperException.Code.NONODE, ((KeeperException)e.getCause()).code());
        	Assert.assertTrue(e instanceof KeeperException 
        			&& ((KeeperException)e).getCode() == KeeperException.Code.NONODE.intValue());
        }
    } 

}
