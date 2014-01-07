@echo off
REM Licensed to the Apache Software Foundation (ASF) under one or more
REM contributor license agreements.  See the NOTICE file distributed with
REM this work for additional information regarding copyright ownership.
REM The ASF licenses this file to You under the Apache License, Version 2.0
REM (the "License"); you may not use this file except in compliance with
REM the License.  You may obtain a copy of the License at
REM
REM     http://www.apache.org/licenses/LICENSE-2.0
REM
REM Unless required by applicable law or agreed to in writing, software
REM distributed under the License is distributed on an "AS IS" BASIS,
REM WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
REM See the License for the specific language governing permissions and
REM limitations under the License.

set ZOOCFGDIR=%~dp0%..\conf

@rem Source the zookeeper-env.cmd.
if exist "%ZOOCFGDIR%\zookeeper-env.cmd" (
  call %ZOOCFGDIR%\zookeeper-env.cmd
)

if not defined ZOOCFG (
  set ZOOCFG=zoo.cfg
)

set ZOOCFG=%ZOOCFGDIR%\%ZOOCFG%

if not defined ZOO_LOG_DIR (
  set ZOO_LOG_DIR=%~dp0%..\logs
)

if not defined ZOO_LOG4J_PROP (
  set ZOO_LOG4J_PROP=INFO,CONSOLE
)

if defined JAVA_HOME (
   set JAVA="%JAVA_HOME%\bin\java"
) else (
  set JAVA=java
)

REM add the zoocfg dir to classpath
set CLASSPATH=%ZOOCFGDIR%;%CLASSPATH%

REM make it work in the release
SET CLASSPATH=%~dp0..\*;%~dp0..\lib\*;%CLASSPATH%

REM make it work for developers
SET CLASSPATH=%~dp0..\build\classes;%~dp0..\build\lib\*;%CLASSPATH%

REM default heap for zookeeper server
if not defined ZK_SERVER_HEAP (
  set ZK_SERVER_HEAP=1000
)
set SERVER_JVMFLAGS=-Xmx%ZK_SERVER_HEAP%m %SERVER_JVMFLAGS%

REM default heap for zookeeper client
if not defined ZK_CLIENT_HEAP (
  set ZK_CLIENT_HEAP=256
)
set CLIENT_JVMFLAGS=-Xmx%ZK_CLIENT_HEAP%m %CLIENT_JVMFLAGS%

@REM setup java environment variables

if not defined JAVA_HOME (
  echo Error: JAVA_HOME is not set.
  goto :eof
)

if not exist %JAVA_HOME%\bin\java.exe (
  echo Error: JAVA_HOME is incorrectly set.
  goto :eof
)

set JAVA=%JAVA_HOME%\bin\java
