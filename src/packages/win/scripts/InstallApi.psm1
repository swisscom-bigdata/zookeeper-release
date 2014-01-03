### Licensed to the Apache Software Foundation (ASF) under one or more
### contributor license agreements.  See the NOTICE file distributed with
### this work for additional information regarding copyright ownership.
### The ASF licenses this file to You under the Apache License, Version 2.0
### (the "License"); you may not use this file except in compliance with
### the License.  You may obtain a copy of the License at
###
###     http://www.apache.org/licenses/LICENSE-2.0
###
### Unless required by applicable law or agreed to in writing, software
### distributed under the License is distributed on an "AS IS" BASIS,
### WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
### See the License for the specific language governing permissions and
### limitations under the License.

###
### A set of basic PowerShell routines that can be used to install and
### manage Hadoop services on a single node. For use-case see install.ps1.
###

###
### Global variables
###
$ScriptDir = Resolve-Path (Split-Path $MyInvocation.MyCommand.Path)
$FinalName = "zookeeper-@version@"
$DefaultRoles = @("zkCli","zkServer")
$WaitingTime = 10000

###############################################################################
###
### Installs Zookeeper.
###
### Arguments:
###     component: Component to be installed, it can be "zookeeper" only
###     nodeInstallRoot: Target install folder (for example "C:\Hadoop")
###     serviceCredential: Credential object used for service creation
###     role: Space separated list of roles that should be installed.
###
###############################################################################
function Install(
    [String]
    [Parameter( Position=0, Mandatory=$true )]
    $component,
    [String]
    [Parameter( Position=1, Mandatory=$true )]
    $nodeInstallRoot,
    [System.Management.Automation.PSCredential]
    [Parameter( Position=2, Mandatory=$false )]
    $serviceCredential,
    [String]
    [Parameter( Position=3, Mandatory=$false )]
    $roles
    )
{
    if ( $component -eq "zookeeper" )
    {
        $HDP_INSTALL_PATH, $HDP_RESOURCES_DIR = Initialize-InstallationEnv $scriptDir "$FinalName.winpkg.log"

        ### $zookeeperInstallDir: the directory that contains the application, after unzipping
        $zookeeperInstallToDir = Join-Path "$nodeInstallRoot" "$FinalName"
        $zookeeperInstallToBin = Join-Path "$zookeeperInstallToDir" "bin"
        Write-Log "zookeeperInstallToDir: $zookeeperInstallToDir"

        CheckRole $roles $DefaultRoles

        InstallBinaries $nodeInstallRoot $serviceCredential

        ###
        ### Create Zookeeper Windows Services and grant user ACLS to start/stop
        ###
        Write-Log "Zookeeper Role Services: $roles"
        $allServices = $roles

        Write-Log "Installing services $allServices"

        foreach( $service in empty-null $allServices.Split(' '))
        {
            if ( $service -eq "zkCli" )
            {
                ### Just install the binaries for the ZK client
                continue
            }
            ### else configure zkServer

            CreateAndConfigureService $service $HDP_RESOURCES_DIR $zookeeperInstallToBin $serviceCredential

            Write-Log "Creating service config ${zookeeperInstallToBin}\$service.xml"
            $cmd = "$zookeeperInstallToBin\zkServer.cmd --service $service catservicexml > `"$zookeeperInstallToBin\$service.xml`""
            Invoke-CmdChk $cmd

            ###
            ### Grant zk server access to $zookeeperInstallToDir
            ###
            if ( $serviceCredential -ne $null )
            {
                $username = $serviceCredential.UserName
                Write-Log "Giving full permissions on `"$zookeeperInstallToDir`" to user `"$username`""
                GiveFullPermissions $zookeeperInstallToDir $username
            }
            else
            {
                $serviceId = "NT SERVICE\$service"
                Write-Log "Giving full permissions on `"$zookeeperInstallToDir`" to service `"$serviceId`""
                GiveFullPermissions $zookeeperInstallToDir """$serviceId"""
            }
        }

        ### Configure the default log locations
        $zookeeperlogsdir = "zookeeperInstallToDir\logs"
        if (Test-Path ENV:ZOO_LOG_DIR)
        {
            $zookeeperlogsdir = "$ENV:ZOO_LOG_DIR"
        }
    }
    else
    {
        throw "Install: Unsupported component argument."
    }
}

###############################################################################
###
### Uninstalls Zookeeper component.
###
### Arguments:
###     component: Component to be uninstalled, it can be "zookeeper"
###     nodeInstallRoot: Install folder (for example "C:\Hadoop")
###
###############################################################################
function Uninstall(
    [String]
    [Parameter( Position=0, Mandatory=$true )]
    $component,
    [String]
    [Parameter( Position=1, Mandatory=$true )]
    $nodeInstallRoot
    )
{
    if ( $component -eq "zookeeper" )
    {
        $HDP_INSTALL_PATH, $HDP_RESOURCES_DIR = Initialize-InstallationEnv $scriptDir "$FinalName.winpkg.log"

        ### $zookeeperInstallDir: the directory that contains the application, after unzipping
        $zookeeperInstallToDir = Join-Path "$nodeInstallRoot" "$FinalName"
        Write-Log "zookeeperInstallToDir: $zookeeperInstallToDir"

        ###
        ### Stop and delete services (no need to stop/delete the "zkCli")
        ###
        foreach( $service in $DefaultRoles)
        {
            StopAndDeleteHadoopService $service
        }

        ###
        ### Delete the Zookeeper directory
        ###
        Write-Log "Deleting $zookeeperInstallToDir"
        $cmd = "rd /s /q `"$zookeeperInstallToDir`""
        Invoke-Cmd $cmd

        ###
        ### Removing ZOOKEEPER_HOME environment variable
        ###
        Write-Log "Removing ENV:ZOOKEEPER_HOME at machine scope"
        [Environment]::SetEnvironmentVariable( "ZOOKEEPER_HOME", $null, [EnvironmentVariableTarget]::Machine )
    }
    else
    {
        throw "Uninstall: Unsupported compoment argument."
    }
}

### Helper routine to return the IPAddress given a hostname
function GetIPAddress($hostname)
{
    try
    {
        [System.Net.Dns]::GetHostAddresses($hostname) | ForEach-Object { if ($_.AddressFamily -eq "InterNetwork") { $_.IPAddressToString } }
    }
    catch
    {
        throw "Error resolving IPAddress for host '$hostname'"
    }
}

### Helper routine to check if two hosts are the same
function IsSameHost(
    [string]
    [parameter( Position=0, Mandatory=$true )]
    $host1,
    [array]
    [parameter( Position=1, Mandatory=$false )]
    $host2ips = ((GetIPAddress $ENV:COMPUTERNAME) -as [array]))
{
    $host1ips = ((GetIPAddress $host1) -as [array])
    $heq = Compare-Object $host1ips $host2ips -ExcludeDifferent -IncludeEqual
    return ($heq -ne $null)
}

### Helper routine to check if the current host matches the given hostname
### Routine does not throw, instead returns false if any of its internal calls throw
function IsCurrentHostNoThrow(
    [string]
    [parameter( Position=0, Mandatory=$true )]
    $hostname)
{
    try
    {
        return IsSameHost $hostname
    }
    catch
    {
        return $false
    }
}

### Configures the myid file by looking up input config map and matching
### configs named "myid.<myhostname>" to the current host name.
### Result of a function is the list of configs that did not match.
function ConfigureMyId(
    [string]
    [parameter( Position=0, Mandatory=$true )]
    $cfgFile,
    [hashtable]
    [parameter( Position=1 )]
    $config = @{} )
{
    # Lookup the value of the dataDir property (value could reside in the existing
    # or in input configs hashtable)
    Write-Log "Configuring my id"

    # Use the hashtable value if present
    [string]$dataDir = $null
    foreach( $key in empty-null $config.Keys )
    {
        $value = $config[$key]
        if ( $key.equals('dataDir', "InvariantCultureIgnoreCase") )
        {
            $dataDir = $value
            Write-Log "dataDir value found in the input config params, dataDir: $dataDir"
            break
        }
    }

    if ( -not $dataDir )
    {
        # Check the cfg file for value
        $lines = [System.IO.File]::ReadAllLines($cfgFile)
        for ( $i = 0; $i -lt $lines.Length; ++$i )
        {
            $line = $lines[$i]
            if ($line.StartsWith("dataDir=", "InvariantCultureIgnoreCase"))
            {
                $dataDir = $line.substring(8)
                Write-Log "dataDir value found in the existing cfg file, dataDir: $dataDir"
                break
            }
        }
    }
    
    if ( -not $dataDir )
    {
        throw "No dataDir property found in input params or cfg file."
    }

    [hashtable]$newConfig = @{}

    foreach( $key in empty-null $config.Keys )
    {
        [string]$keyString = $key
        $value = $config[$key]
        if ( $keyString.StartsWith("myid.", "CurrentCultureIgnoreCase") )
        {
            ### Check if myid.<hostname> matches current machine hostname
            [string]$hostName = $keyString.substring(5)
            if ( IsCurrentHostNoThrow $hostName )
            {
                Write-Log "My id: $value"
                $myIdFile = Join-Path $dataDir "myid"
                New-Item $myIdFile -type file -force -value $value > $null
            }
            ### else do nothing as don't want myid config in the cfg file
        }
        else
        {
            $newConfig.Add($keyString, $value) > $null
        }
    }

    $newConfig
}

###############################################################################
###
### Alters the configuration of the component.
###
### Arguments:
###     component: Component to be configured, "zookeeper"
###     nodeInstallRoot: Target install folder (for example "C:\Hadoop")
###     serviceCredential: Credential object used for service creation
###     configs: Configuration that should be applied.
###              For example, @{"fs.checkpoint.edits.dir" = "C:\Hadoop\hdfs\2nne"}
###              Some configuration parameter are aliased, see ProcessAliasConfigOptions
###              for details.
###     aclAllFolders: If true, all folders defined in config file will be ACLed
###                    If false, only the folders listed in $configs will be ACLed.
###
###############################################################################
function Configure(
    [String]
    [Parameter( Position=0, Mandatory=$true )]
    $component,
    [String]
    [Parameter( Position=1, Mandatory=$true )]
    $nodeInstallRoot,
    [System.Management.Automation.PSCredential]
    [Parameter( Position=2, Mandatory=$false )]
    $serviceCredential,
    [hashtable]
    [parameter( Position=3 )]
    $configs = @{},
    [bool]
    [parameter( Position=4 )]
    $aclAllFolders = $True
    )
{
    if ( $component -eq "zookeeper" )
    {
        $HDP_INSTALL_PATH, $HDP_RESOURCES_DIR = Initialize-InstallationEnv $scriptDir "$FinalName.winpkg.log"

        ### $zookeeperInstallDir: the directory that contains the application, after unzipping
        $zookeeperInstallToDir = Join-Path "$nodeInstallRoot" "$FinalName"
        $zookeeperInstallToBin = Join-Path "$zookeeperInstallToDir" "bin"
        Write-Log "zookeeperInstallToDir: $zookeeperInstallToDir"

        if( -not (Test-Path $zookeeperInstallToDir ))
        {
            throw "ConfigureZookeeper: Install the zookeeper before configuring it"
        }

        $cfgFile = Join-Path "$zookeeperInstallToDir" "conf\zoo.cfg"

        ### Apply myid configuration if passed
        [hashtable]$configs = ConfigureMyId $cfgFile $configs

        ###
        ### Apply configuration changes to zoo.cfg
        ###
        UpdateTextConfig $cfgFile $configs
    }
    else
    {
        throw "Configure: Unsupported component argument."
    }
}

###############################################################################
###
### Start component services.
###
### Arguments:
###     component: Component name
###     roles: List of space separated service to start
###
###############################################################################
function StartService(
    [String]
    [Parameter( Position=0, Mandatory=$true )]
    $component,
    [String]
    [Parameter( Position=1, Mandatory=$true )]
    $roles
    )
{
    Write-Log "Starting `"$component`" `"$roles`" services"

    if ( $component -eq "zookeeper" )
    {
        ### Verify that roles are in the supported set
        CheckRole $roles $DefaultRoles

        foreach ( $role in $roles.Split(" ") )
        {
            if ( $role -eq "zkCli" )
            {
                Write-Log "Zookeeper client does not have any services"
            }
            else
            {
                Write-Log "Starting $role service"
                Start-Service $role
            }
        }
    }
    else
    {
        throw "StartService: Unsupported component argument."
    }
}

###############################################################################
###
### Stop component services.
###
### Arguments:
###     component: Component name
###     roles: List of space separated service to stop
###
###############################################################################
function StopService(
    [String]
    [Parameter( Position=0, Mandatory=$true )]
    $component,
    [String]
    [Parameter( Position=1, Mandatory=$true )]
    $roles
    )
{
    Write-Log "Stopping `"$component`" `"$roles`" services"

    if ( $component -eq "zookeeper" )
    {
        ### Verify that roles are in the supported set
        CheckRole $roles $DefaultRoles

        foreach ( $role in $roles.Split(" ") )
        {
            if ( $role -eq "zkCli" )
            {
                Write-Log "Zookeeper client does not have any services"
            }
            else
            {
                try
                {
                    Write-Log "Stopping $role "
                    if (Get-Service "$role" -ErrorAction SilentlyContinue)
                    {
                        Write-Log "Service $role exists, stopping it"
                        Stop-Service $role
                    }
                    else
                    {
                        Write-Log "Service $role does not exist, moving to next"
                    }
                }
                catch [Exception]
                {
                    Write-Host "Can't stop service $role"
                }
            }
        }
    }
    else
    {
        throw "StartService: Unsupported component argument."
    }
}

###############################################################################
###
### Installs Zookeeper binaries.
###
### Arguments:
###     nodeInstallRoot: Target install folder (for example "C:\Hadoop")
###
###############################################################################
function InstallBinaries(
    [String]
    [Parameter( Position=0, Mandatory=$true )]
    $nodeInstallRoot,
    [System.Management.Automation.PSCredential]
    [Parameter( Position=1, Mandatory=$false )]
    $serviceCredential
    )
{
    $HDP_INSTALL_PATH, $HDP_RESOURCES_DIR = Initialize-InstallationEnv $scriptDir "$FinalName.winpkg.log"

    ### $zookeeperInstallDir: the directory that contains the application, after unzipping
    $zookeeperInstallToDir = Join-Path "$nodeInstallRoot" "$FinalName"
    $zookeeperLogsDir = Join-Path "$zookeeperInstallToDir" "logs"
    if (Test-Path ENV:ZOO_LOG_DIR)
    {
        $zookeeperLogsDir = "$ENV:ZOO_LOG_DIR"
    }
    Write-Log "zookeeperLogsDir: $zookeeperLogsDir"

    Write-Log "Checking the JAVA Installation."
    if( -not (Test-Path $ENV:JAVA_HOME\bin\java.exe))
    {
      Write-Log "JAVA_HOME not set properly; $ENV:JAVA_HOME\bin\java.exe does not exist" "Failure"
      throw "Install: JAVA_HOME not set properly; $ENV:JAVA_HOME\bin\java.exe does not exist."
    }

    ###
    ### Set ZOOKEEPER_HOME environment variable
    ###
    Write-Log "Setting the ZOOKEEPER_HOME environment variable at machine scope to `"$zookeeperInstallToDir`""
    [Environment]::SetEnvironmentVariable("ZOOKEEPER_HOME", $zookeeperInstallToDir, [EnvironmentVariableTarget]::Machine)
    $ENV:ZOOKEEPER_HOME = $zookeeperInstallToDir

    ### Zookeeper Binaries must be installed before creating the services
    ###
    ### Begin install
    ###
    Write-Log "Installing Apache Zookeeper $FinalName to $nodeInstallRoot"

    ### Create Node Install Root directory
    if( -not (Test-Path "$nodeInstallRoot"))
    {
        Write-Log "Creating Node Install Root directory: `"$nodeInstallRoot`""
        New-Item -Path "$nodeInstallRoot" -type directory | Out-Null
    }

    ###
    ###  Unzip Zookeeper distribution from compressed archive
    ###
    Write-Log "Extracting Zookeeper archive into $zookeeperInstallToDir"
    if ( Test-Path ENV:UNZIP_CMD )
    {
        ### Use external unzip command if given
        $unzipExpr = $ENV:UNZIP_CMD.Replace("@SRC", "`"$HDP_RESOURCES_DIR\$FinalName.zip`"")
        $unzipExpr = $unzipExpr.Replace("@DEST", "`"$nodeInstallRoot`"")
        ### We ignore the error code of the unzip command for now to be
        ### consistent with prior behaviour.
        Invoke-Ps $unzipExpr
    }
    else
    {
        $shellApplication = new-object -com shell.application
        $zipPackage = $shellApplication.NameSpace("$HDP_RESOURCES_DIR\$FinalName.zip")
        $destinationFolder = $shellApplication.NameSpace($nodeInstallRoot)
        $destinationFolder.CopyHere($zipPackage.Items(), 20)
    }

    ###
    ###  Copy template config files
    ###
    Write-Log "Copying template files"
    $xcopy_cmd = "xcopy /EIYF `"$HDP_INSTALL_PATH\..\template`" `"$zookeeperInstallToDir`""
    Invoke-Cmd $xcopy_cmd

    ###
    ### ACL Zookeeper logs directory such that machine users can write to it
    ###
    if( -not (Test-Path "$zookeeperLogsDir"))
    {
        Write-Log "Creating Zookeeper logs folder"
        New-Item -Path "$zookeeperLogsDir" -type directory | Out-Null
    }
    GiveFullPermissions "$zookeeperLogsDir" "Users"

    Write-Log "Installation of Apache Zookeeper binaries completed"
}


### Helper routing that converts a $null object to nothing. Otherwise, iterating over
### a $null object with foreach results in a loop with one $null element.
function empty-null($obj)
{
   if ($obj -ne $null) { $obj }
}

### Gives full permissions on the folder to the given user
function GiveFullPermissions(
    [String]
    [Parameter( Position=0, Mandatory=$true )]
    $folder,
    [String]
    [Parameter( Position=1, Mandatory=$true )]
    $username)
{
    Write-Log "Giving user/group `"$username`" full permissions to `"$folder`""
    $cmd = "icacls `"$folder`" /grant ${username}:(OI)(CI)F"
    Invoke-CmdChk $cmd
}

### Checks if the given space separated roles are in the given array of
### supported roles.
function CheckRole(
    [string]
    [parameter( Position=0, Mandatory=$true )]
    $roles,
    [array]
    [parameter( Position=1, Mandatory=$true )]
    $supportedRoles
    )
{
    foreach ( $role in $roles.Split(" ") )
    {
        if ( -not ( $supportedRoles -contains $role ) )
        {
            throw "CheckRole: Passed in role `"$role`" is outside of the supported set `"$supportedRoles`""
        }
    }
}

function CreateAndConfigureService(
    [String]
    [Parameter( Position=0, Mandatory=$true )]
    $service,
    [String]
    [Parameter( Position=1, Mandatory=$true )]
    $hdpResourcesDir,
    [String]
    [Parameter( Position=2, Mandatory=$true )]
    $serviceBinDir,
    [System.Management.Automation.PSCredential]
    [Parameter( Position=3, Mandatory=$false )]
    $serviceCredential
)
{
    if ( $serviceCredential -eq $null )
    {
        CreateAndConfigureServiceAsVirtualAccount $service $hdpResourcesDir $serviceBinDir
    }
    else
    {
        CreateAndConfigureServiceAsUserAccount $service $hdpResourcesDir $serviceBinDir $serviceCredential
    }
}

function CreateAndConfigureServiceAsUserAccount(
    [String]
    [Parameter( Position=0, Mandatory=$true )]
    $service,
    [String]
    [Parameter( Position=1, Mandatory=$true )]
    $hdpResourcesDir,
    [String]
    [Parameter( Position=2, Mandatory=$true )]
    $serviceBinDir,
    [System.Management.Automation.PSCredential]
    [Parameter( Position=3, Mandatory=$true )]
    $serviceCredential
)
{
    if ( -not ( Get-Service "$service" -ErrorAction SilentlyContinue ) )
    {
        Write-Log "Creating service `"$service`" as $serviceBinDir\$service.exe"
        $xcopyServiceHost_cmd = "copy /Y `"$hdpResourcesDir\serviceHost.exe`" `"$serviceBinDir\$service.exe`""
        Invoke-CmdChk $xcopyServiceHost_cmd

        #HadoopServiceHost.exe will write to this log but does not create it
        #Creating the event log needs to be done from an elevated process, so we do it here
        if( -not ([Diagnostics.EventLog]::SourceExists( "$service" )))
        {
            [Diagnostics.EventLog]::CreateEventSource( "$service", "" )
        }

        Write-Log "Adding service $service"
        if ($serviceCredential.Password.get_Length() -ne 0)
        {
            $s = New-Service -Name "$service" -BinaryPathName "$serviceBinDir\$service.exe" -Credential $serviceCredential -DisplayName "Apache Hadoop $service"
            if ( $s -eq $null )
            {
                throw "CreateAndConfigureServiceAsUserAccount: Service `"$service`" creation failed"
            }
        }
        else
        {
            # Separately handle case when password is not provided
            # this path is used for creating services that run under (AD) Managed Service Account
            # for them password is not provided and in that case service cannot be created using New-Service commandlet
            $serviceUserName = $serviceCredential.UserName
            $cmd="$ENV:WINDIR\system32\sc.exe create `"$service`" binPath= `"$serviceBinDir\$service.exe`" obj= $serviceUserName DisplayName= `"Apache Hadoop $service`" "
            try
            {
                Invoke-CmdChk $cmd
            }
            catch
            {
                throw "CreateAndConfigureServiceAsUserAccount: Service `"$service`" creation failed"
            }
        }

        $cmd="$ENV:WINDIR\system32\sc.exe failure $service reset= 30 actions= restart/5000"
        Invoke-CmdChk $cmd

        $cmd="$ENV:WINDIR\system32\sc.exe config $service start= demand"
        Invoke-CmdChk $cmd

        Set-ServiceAcl $service
    }
    else
    {
        Write-Log "Service `"$service`" already exists, skipping service creation"
    }
}

function CreateAndConfigureServiceAsVirtualAccount(
    [String]
    [Parameter( Position=0, Mandatory=$true )]
    $service,
    [String]
    [Parameter( Position=1, Mandatory=$true )]
    $hdpResourcesDir,
    [String]
    [Parameter( Position=2, Mandatory=$true )]
    $serviceBinDir
)
{
    if ( -not ( Get-Service "$service" -ErrorAction SilentlyContinue ) )
    {
        Write-Log "Creating service `"$service`" as $serviceBinDir\$service.exe"
        $xcopyServiceHost_cmd = "copy /Y `"$hdpResourcesDir\serviceHost.exe`" `"$serviceBinDir\$service.exe`""
        Invoke-CmdChk $xcopyServiceHost_cmd

        #HadoopServiceHost.exe will write to this log but does not create it
        #Creating the event log needs to be done from an elevated process, so we do it here
        if( -not ([Diagnostics.EventLog]::SourceExists( "$service" )))
        {
            [Diagnostics.EventLog]::CreateEventSource( "$service", "" )
        }

        Write-Log "Adding service $service"

        $cmd="$ENV:WINDIR\system32\sc.exe create `"$service`" binPath= `"$serviceBinDir\$service.exe`" obj= `"NT SERVICE\$service`" DisplayName= `"Apache Hadoop $service`" " 
        try
        {
            Invoke-CmdChk $cmd
        }
        catch
        {
            throw "CreateAndConfigureServiceAsVirtualAccount: Service `"$service`" creation failed"
        }

        $cmd="$ENV:WINDIR\system32\sc.exe failure $service reset= 30 actions= restart/5000"
        Invoke-CmdChk $cmd

        $cmd="$ENV:WINDIR\system32\sc.exe config $service start= demand"
        Invoke-CmdChk $cmd

        Set-ServiceAcl $service
    }
    else
    {
        Write-Log "Service `"$service`" already exists, Removing `"$service`""
        StopAndDeleteHadoopService $service
        CreateAndConfigureServiceAsVirtualAccount $service $hdpResourcesDir $serviceBinDir
    }
}

### Forces a service to stop
function ForceStopService(
    [ServiceProcess.ServiceController]
    [Parameter( Position=0, Mandatory=$true )]
    $s
)
{
    Stop-Service -InputObject $s -Force
    $ServiceProc = Get-Process -Id (Get-WmiObject win32_Service | Where {$_.Name -eq $s.Name}).ProcessId -ErrorAction SilentlyContinue
    if( $ServiceProc.Id -ne 0 )
    {
        if( $ServiceProc.WaitForExit($WaitingTime) -eq $false )
        {
            Write-Log "Process $ServiceProc cannot be stopped. Trying to kill the process"
            Stop-Process $ServiceProc -Force  -ErrorAction Continue
        }
     }
}

### Stops and deletes the Hadoop service.
function StopAndDeleteHadoopService(
    [String]
    [Parameter( Position=0, Mandatory=$true )]
    $service
)
{
    Write-Log "Stopping $service"
    $s = Get-Service $service -ErrorAction SilentlyContinue
    if( $s -ne $null )
    {
        try
        {
            ForceStopService $s
        }
        catch
        {
            Write-Log "ForceStopService: Failed with exception: $($_.Exception.ToString())"
        }
        $cmd = "sc.exe delete $service"
        Invoke-Cmd $cmd
    }
}

### Helper routine that updates the given text file with the given
### key/value configuration values. The text file is expected to be 
### a simple key=value pair.
### <configuration>
function UpdateTextConfig(
    [string]
    [parameter( Position=0, Mandatory=$true )]
    $fileName,
    [hashtable]
    [parameter( Position=1 )]
    $config = @{} )
{
    $lines = [System.IO.File]::ReadAllLines($fileName)
    $newLines = @()
    
    foreach( $key in empty-null $config.Keys )
    {
        $foundMatch = $false
        $value = $config[$key]
        for ( $i = 0; $i -lt $lines.Length; ++$i )
        {
            $line = $lines[$i]
            if ($line.StartsWith("$key=", "InvariantCultureIgnoreCase"))
            {
                $lines[$i] = "$key=$value"
                $foundMatch = $true
            }
        }

        if ( -not $foundMatch )
        {
            $newLines += "$key=$value"
        }
    }
    
    $allLines = $lines + $newLines
    
    [System.IO.File]::WriteAllLines($fileName, $allLines)
}

### Helper routine that ACLs the folders defined in folderList properties.
### The routine will look for the property value in the given xml config file
### and give full permissions on that folder to the given username.
###
### Dev Note: All folders that need to be ACLed must be defined in *-site.xml
### files.
function AclFoldersForUser(
    [string]
    [parameter( Position=0, Mandatory=$true )]
    $xmlFileName,
    [string]
    [parameter( Position=1, Mandatory=$true )]
    $username,
    [array]
    [parameter( Position=2, Mandatory=$true )]
    $folderList )
{
    $xml = [xml] (Get-Content $xmlFileName)

    foreach( $key in empty-null $folderList )
    {
        $folderName = $null
        $xml.SelectNodes('/configuration/property') | ? { $_.name -eq $key } | % { $folderName = $_.value }
        if ( $folderName -eq $null )
        {
            throw "AclFoldersForUser: Trying to ACLs the folder $key which is not defined in $xmlFileName"
        }

        ### TODO: Support for JBOD and NN Replication
        $folderParent = Split-Path $folderName -parent

        if( -not (Test-Path $folderParent))
        {
            Write-Log "AclFoldersForUser: Creating Directory `"$folderParent`" for ACLing"
            mkdir $folderParent

            ### TODO: ACL only if the folder does not exist. Otherwise, assume that
            ### it is ACLed properly.
            GiveFullPermissions $folderParent $username
        }
    }

    $xml.ReleasePath
}

###
### Public API
###
Export-ModuleMember -Function Install
Export-ModuleMember -Function Uninstall
Export-ModuleMember -Function Configure
Export-ModuleMember -Function StartService
Export-ModuleMember -Function StopService
Export-ModuleMember -Function UpdateTextConfig
Export-ModuleMember -Function ConfigureMyId
