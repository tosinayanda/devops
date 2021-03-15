
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
param ([string]$connectionString,[string]$serverName,[string]$databaseName,[string]$backupLocation,[string]$backupFileName)

####
## Declare Global Variables
####
$CPU = $env:COMPUTERNAME
$DEPENDENCIES = @('SqlServer','Write-Log')

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

function Verify-BackupLocationExists {

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
write-host -ForegroundColor Green "************************************************************"

# Install Module Dependencies

Install-Dependencies -Modules $DEPENDENCIES


<# Validate Input
Verify-ServerExistsAndReachable -a "QADH10TSLT14675"
Verify-BackupLocationExists -path "C:\logs"


!(Verify-ServerExistsAndReachable -a "QADH10TSLT14676")
!(Verify-BackupLocationExists -path "C:\lbus")
#>

if((Verify-ServerExistsAndReachable -a "QADH10TSLT14675") -ne $true)
{
    write-host -ForegroundColor Red "Server is not Reachable"    
}
elseif((Verify-BackupLocationExists -path "C:\logs") -ne $true)
{
    write-host -ForegroundColor Red "Backup Path Does Not exist"    
}
# Perform Backup
else
{
    write-host -ForegroundColor Yello "Starting Backup"
    #Backup-SqlDatabase -ServerInstance "." -Database "testdb" -BackupFile "c:\sql\testDB.bak"
    $extension = ".bak"
    $backupPath = $backupLocation +$backupFileName+$extension
    if(Test-Path -Path $backupPath -PathType Leaf)
    {
        $currentTimeStamp = Get-Date -Format "dddd MM-dd-yyyy HH:mm K"
        $renamedPath = $backupPath.Replace($extension,$currentTimeStamp +$extension)
        Rename-Item -Path $backupPath -NewName $renamedPath
    }
    write-host -ForegroundColor White "Backup Path is $backupPath"
    Backup-SqlDatabase -ServerInstance $serverName -Database $databaseName -BackupFile $backupPath
}


write-host -ForegroundColor Green "************************************************************"
write-host -ForegroundColor White "Stopping PowerShell Script Execution"
write-host -ForegroundColor Green "************************************************************"
