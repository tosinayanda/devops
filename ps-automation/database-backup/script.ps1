
<####
## Sources
https://sqlbackupandftp.com/blog/powershell-how-to-backup-and-recover-an-sql-server-database-faq
https://devblogs.microsoft.com/scripting/weekend-scripter-best-practices-for-powershell-scripting-in-shared-environment/
https://www.scalyr.com/blog/getting-started-quickly-powershell-logging/
https://www.varonis.com/blog/powershell-array/
https://www.varonis.com/blog/windows-powershell-tutorials/
https://adamtheautomator.com/powershell-check-if-file-exists/
####>


####
## Declare Arguments
####
param ([string]$connectionString,
       [string]$serverName,
       [string]$databaseName,
       [string]$backupLocation,
       [string]$backupFileName,
       [switch]$UseConnectionString = $false)

####
## Declare Global Variables
####
$CPU = $env:COMPUTERNAME
$CURRENT_USER = $env:UserName
$DEPENDENCIES = @('SqlServer','Write-Log');
$DEFAULT_BACKUP_LOCATION = 'C:\db\backup';
$DEFAULT_BACKUP_FILENAME = "backup.bak";



####
## Declare Functions
####
function Log {
    param(
        [Parameter(Mandatory=$true)][String]$msg
    )

    $logPath = "C:\log\log.txt"

    Add-Content log.txt $msg
    Write-Log -Message "Intermediate result: $($sum)" -Level Info -Path $logPath
}

function Load-Module ($m) {

    # If module is imported say that and do nothing
    if (Get-Module | Where-Object {$_.Name -eq $m}) {
        write-host "Module $m is already imported."
    }
    else {

        # If module is not imported, but available on disk then import
        if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $m}) {
            Import-Module $m -Verbose
        }
        else {

            # If module is not imported, not available on disk, but is in online gallery then install and import
            if (Find-Module -Name $m | Where-Object {$_.Name -eq $m}) {
                Install-Module -Name $m -Force -Verbose -Scope CurrentUser
                Import-Module $m -Verbose
            }
            else {

                # If module is not imported, not available and not in online gallery then abort
                write-host "Module $m not imported, not available and not in online gallery, exiting."
                EXIT 1
            }
        }
    }
}
# Load-Module "ModuleName"

function Install-Dependencies
{
    param(
        [Parameter(Mandatory=$true)][String[]]$Modules
    )

    # Set Execution Policy
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

    # Install-Module -Name SqlServer -Scope CurrentUser
    # Install-Module -Name Write-Log -Scope CurrentUser -Force
    # Get-InstalledModule  -Name "SqlServer" ErrorAction SilentlyContinue

    try 
    {

        ForEach($module in $Modules) 
        {
        
        # "Item: [$PSItem]"
            Write-Host "Importing [$module]"

            if ((Get-InstalledModule  -Name $module) -eq $null) 
            {
                Write-Host "Installing Module"
                # Install it...
                Install-Module -Name $module -Scope CurrentUser -Force
                
                Write-Host "Successfully Installed Module"
            }
        }
        
        # Import-Module SomeModule
        # Write-Host "Module exists"
    } 
    catch
    {
        Write-Host "Unable to Complete Installation of Module Dependencies"
        Write-Output $PSItem.ToString()
        throw "Unable to Complete Installation of Module Dependencies"
    }

}

function Verify-LocationExists {

    Param ([string]$path,
           [bool]$createDirectory = $false)

    if (Test-Path -Path $path -IsValid) 
    { 
        if (Test-Path -Path $path) 
        { 
             Write-Output True
        }
        else
        {
            Write-Output False
    
        }
    }
    else
    {
        Write-Output False
    
    }

}

function Verify-ServerExistsAndReachable {

    Param ([string]$a)

    if (Test-Connection -ComputerName $a -Quiet) 
    { 
         Write-Output True
    }
    else
    {
    
        Write-Output False
    }

}

function Test-MrCmdletBinding {

    [CmdletBinding()] #<<-- This turns a regular function into an advanced function
    param (
        $ComputerName
    )

    Write-Output $ComputerName
}


# Main Program
write-host -ForegroundColor Green "************************************************************"
write-host -ForegroundColor White "Starting PowerShell Script Execution"
write-host -ForegroundColor Green "Title : Backup Database"
write-host -ForegroundColor Green "Hostname : $CPU"
write-host -ForegroundColor Green "************************************************************"

# Install Module Dependencies

Install-Dependencies -Modules $DEPENDENCIES


<# Validate Input
Verify-ServerExistsAndReachable -a "QADH10TSLT14675"
Verify-BackupLocationExists -path "C:\logs"


!(Verify-ServerExistsAndReachable -a "QADH10TSLT14676")
!(Verify-BackupLocationExists -path "C:\lbus")
#>

if($UseConnectionString)
{

    #Loading the SMO assembly into your PowerShell session. You can actually do this by simply loading the full SQLPS module, as that will automatically load the assembly
    #Add-Type -AssemblyName "Microsoft.SqlServer.Smo,Version=11.0.0.0,Culture=neutral,PublicKeyToken=89845dcd8080cc91"
    #Install-Module -Name Microsoft.SqlServer.Smo -Scope CurrentUser -Force
    #System.Reflection.Assembly::LoadWithPartialName("Microsoft.SqlServer.Smo")
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")

    try
    {
        # Create Connection
        Write-Host -ForegroundColor Yellow "Creating Connection Object ...."
        $sqlConn = New-Object System.Data.SqlClient.SqlConnection
        $sqlConn.ConnectionString = ?$connectionString?
        $sqlConn.Open()
        Write-Host -ForegroundColor Green "Connection Established"

        # Create Backup
        write-host -ForegroundColor Yello "Starting Backup"
        #$databaseName = $connectionString.Split()
        $databaseName = "pob-test"

        $sqlcmd = $sqlConn.CreateCommand()
        <# or 
        
         $sqlcmd = New-Object System.Data.SqlClient.SqlCommand
         
         #>
        # Create Directory If It Does Not Exist
        if((Verify-LocationExists -path "$DEFAULT_BACKUP_LOCATION\$CURRENT_USER") -ne $true)
        {
            New-Item -Path "$DEFAULT_BACKUP_LOCATION\$CURRENT_USER" -ItemType Directory        
        }

        $backupPath = "$DEFAULT_BACKUP_LOCATION\$CURRENT_USER\$DEFAULT_BACKUP_FILENAME"

        $sqlcmd.Connection = $sqlConn
        $query = ?BACKUP DATABASE [@dbname] TO DISK=@diskpath?
        Write-Host $query         #Use Parameterised Query in the Command        $sqlcmd.CommandText = $query
        $sqlcmd.Parameters.Add("@dbname", $databaseName);
        $sqlcmd.Parameters.Add("@diskpath", $backupPath);

        $sqlcmd.CommandTimeout = 0


        $sqlcmd.ExecuteNonQuery() | Out-Null

        write-host -ForegroundColor Yello "Backup Completed"


    }
    catch
    {
        Write-Host -ForegroundColor Red "Unable to Complete DataBase Backup"
        Write-Output $PSItem.ToString()
    }
    finally
    {
        if($sqlConn -ne $null)
        {
            Write-Host -ForegroundColor Yellow "Closing Connection ...."
            $sqlConn.Close()
            Write-Host -ForegroundColor Green "Connection Terminated"

        }
    }
    

}
else
{
    #Provide Computer Name as Default Value For Server, If Empty
    #if(($serverName -eq '.') -or ($serverName -eq ''))
    if(([string]::IsNullOrEmpty($serverName)) -or ($serverName -eq $null))
    {
        $serverName = $CPU;
    }

    if((Verify-ServerExistsAndReachable -a $serverName) -ne $true)
    {
        write-host -ForegroundColor Red "Server $serverName is not Reachable"    
    }
    elseif((Verify-LocationExists -path $backupPath) -ne $true)
    {
        write-host -ForegroundColor Red "Backup $backupPath Path Does Not exist"    
    }
    # Perform Backup
    else
    {
        write-host -ForegroundColor Yello "Starting Backup"
        #Backup-SqlDatabase -ServerInstance "." -Database "testdb" -BackupFile "c:\sql\testDB.bak"
        $extension = ".bak"
        $backupPath=''
        $backupPath = "$backupLocation$backupFileName$extension"

         # Check If File With Matching Name Found
        if(Test-Path -Path $backupPath -PathType Leaf)
        {
            # Rename Old Backup File
            $currentTimeStamp = Get-Date -Format "MM-dd-yyyy HH:mm:ss"
            $renamedPath = $backupPath.Replace($extension,$currentTimeStamp +$extension)
            Rename-Item -Path $backupPath -NewName $renamedPath
        }
        write-host -ForegroundColor White "Backup Path is $backupPath"
        Backup-SqlDatabase -ServerInstance $serverName -Database $databaseName -BackupFile $backupPath
    }
}



write-host -ForegroundColor Green "************************************************************"
write-host -ForegroundColor White "Stopping PowerShell Script Execution"
write-host -ForegroundColor Green "************************************************************"
