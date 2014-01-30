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

param(
    [String]
    [Parameter( ParameterSetName='UsernamePassword', Position=0, Mandatory=$true )]
    [Parameter( ParameterSetName='UsernamePasswordBase64', Position=0, Mandatory=$true )]
    $username,
    [String]
    [Parameter( ParameterSetName='UsernamePassword', Position=1, Mandatory=$true )]
    $password,
    [String]
    [Parameter( ParameterSetName='UsernamePasswordBase64', Position=1, Mandatory=$true )]
    $passwordBase64,
    [Parameter( ParameterSetName='CredentialFilePath', Mandatory=$true )]
    $credentialFilePath,
    $zookeeperRole
    )

function Main( $scriptDir )
{
    $FinalName = "zookeeper-@version@"
    if ( -not (Test-Path ENV:WINPKG_LOG))
    {
        $ENV:WINPKG_LOG = "$FinalName.winpkg.log"
    }

    $HDP_INSTALL_PATH, $HDP_RESOURCES_DIR = Initialize-InstallationEnv $scriptDir $ENV:WINPKG_LOG

    ### $zookeeperInstallDir: the directory that contains the appliation, after unzipping
    $nodeInstallRoot = "$ENV:HADOOP_NODE_INSTALL_ROOT"
    $zookeeperInstallDir = Join-Path "$ENV:HADOOP_NODE_INSTALL_ROOT" "$FinalName"
    $zookeeperInstallBin = Join-Path "$zookeeperInstallDir" "bin"

    Write-Log "ZookeeperInstallDir: $zookeeperInstallDir"
    Write-Log "ZookeeperInstallBin: $zookeeperInstallBin" 

    ###
    ### Create the Credential object from the given username and password or the provided credentials file
    ###
    $serviceCredential = Get-HadoopUserCredentials -credentialsHash @{"username" = $username; "password" = $password; `
        "passwordBase64" = $passwordBase64; "credentialFilePath" = $credentialFilePath}
    $username = $serviceCredential.UserName
    Write-Log "Username: $username"
    Write-Log "CredentialFilePath: $credentialFilePath"

    if ("$ENV:IS_ZOOKEEPER" -eq "yes") {
        $zookeeperRole = "zkServer"
    }
    else
    {
        $zookeeperRole = "zkCli"
    }
    ###
    ### Begin install
    ###
    Write-Log "Installing Apache Zookeeper to $zookeeperInstallDir"

    if( $username -eq $null )
    {
        Write-Log "Username cannot be empty" "Failure"
        exit 1
    }

    # strip out domain/machinename if it exists. will not work with domain users.
    $shortUsername = $username
    if($username.IndexOf('\') -ge 0)
    {
        $shortUsername = $username.SubString($username.IndexOf('\') + 1)
    }

    Install "zookeeper" $NodeInstallRoot $serviceCredential $zookeeperRole

    # Updating zoo.cfg
    
    Write-Log "Applying zookeeper configuration"

    if ( -not ( Test-Path ENV:HDP_DATA_DIR ) )
    {
        $ENV:HDP_DATA_DIR = "c:\hdp\data"
    }

    $zkDataDir = Join-Path (${ENV:HDP_DATA_DIR}.Split(",") | Select -first 1).Trim() "zkData"
    # Escape forward slash to make the cfg Windows compatible
    $zkDataDir = $zkDataDir.Replace('\','\\')
    [hashtable]$config = @{"dataDir" = "$zkDataDir"}

    if ( Test-Path ENV:ZOOKEEPER_HOSTS )
    {
        $id = 1
        foreach ( $hostname in $ENV:ZOOKEEPER_HOSTS.Split(",") )
        {
            $serverZkId = "server."+ $id
            $serverLocation = $hostname.Trim() + ":2888:3888"
            $config.Add($serverZkId, $serverLocation) > $null
            $config.Add("myid.$hostname", $id) > $null
            $id++
        }
    }

    Configure "zookeeper" $NodeInstallRoot $serviceCredential $config

    Write-Log "Install of Zookeeper completed successfully!!!"
}

try
{
    $scriptDir = Resolve-Path (Split-Path $MyInvocation.MyCommand.Path)
    $utilsModule = Import-Module -Name "$scriptDir\..\resources\Winpkg.Utils.psm1" -ArgumentList ("ZOOKEEPER") -PassThru
    $apiModule = Import-Module -Name "$scriptDir\InstallApi.psm1" -PassThru
    Main $scriptDir
}
catch
{
    Write-Log $_.Exception.Message "Failure" $_
    exit 1
}
finally
{
    if( $apiModule -ne $null )
    {
        Remove-Module $apiModule
    }
    if( $utilsModule -ne $null )
    {
        Remove-Module $utilsModule
    }
}
