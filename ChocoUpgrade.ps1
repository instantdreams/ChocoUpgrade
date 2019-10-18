## ---- [Script Parameters] ----
Param()


# Function Launch-Process - capture and display output from Start-Process
function Launch-Process
{
    <#
    .SYNOPSIS
        Pass parameters to StartProcess and capture the output
    .DESCRIPTION
        Use temporary files to capture output and errors
    .EXAMPLE
        Launch-Process -Process $ProcessHandler -Arguments $ProcessArguments
    .OUTPUTS
        Log file, process started
    .NOTES
        Version:        1.0
        Author:         Dean Smith | deanwsmith@outlook.com
        Creation Date:  2019-09-18
        Purpose/Change: Initial script creation
    #>
    ## ---- [Function Parameters] ----
    [CmdletBinding()]
    Param([string]$ProcessHandler,[string[]]$ProcessArguments)

    ## ---- [Function Beginning] ----
    Begin {}

    ## ---- [Function Execution] ----
    Process
    {
        Try
        {
            $StdOutTempFile = "$env:TEMP\$((New-Guid).Guid)"
            $StdErrTempFile = "$env:TEMP\$((New-Guid).Guid)"
            $Process = Start-Process -FilePath $ProcessHandler -ArgumentList $ProcessArguments -NoNewWindow -PassThru -Wait -RedirectStandardOutput $StdOutTempFile -RedirectStandardError $StdErrTempFile
            $ProcessOutput = Get-Content -Path $StdOutTempFile -Raw
            $ProcessError  = Get-Content -Path $StdErrTempFile -Raw
            If ($Process.ExitCode -ne 0)
            {
                If ($ProcessError)  { Throw $ProcessError.Trim()  }
                If ($ProcessOutput) { Throw $ProcessOutput.Trim() }
            }
            Else
            {
                If ([string]::IsNullOrEmpty($ProcessOutput) -eq $false) { Write-Output -InputObject $ProcessOutput }
            }
        }
        Catch   { $PSCmdlet.ThrowTerminatingError($_) }
        Finally { Remove-Item -Path $stdOutTempFile, $stdErrTempFile -Force -ErrorAction Ignore }
    }

    ## ---- [Function End] ----
    End {}
}
    

# Function Choco-Upgrade - upgrade chocolatey packages
function Choco-Upgrade
{
    <#
    .SYNOPSIS
        Stop processes, stop services, upgrade packages, start services
    .DESCRIPTION
        Use the details from the configuration file to manage processes and services, then upgrade all packages
    .EXAMPLE
        Choco-Upgrade
    .OUTPUTS
        Log file, upgraded packages
    .NOTES
        Version:        1.0
        Author:         Dean Smith | deanwsmith@outlook.com
        Creation Date:  2019-07-16
        Purpose/Change: Initial script creation
    #>
    ## ---- [Function Parameters] ----
    [CmdletBinding()]
    Param()

    ## ---- [Function Beginning] ----
    Begin {}

    ## ---- [Function Execution] ----
    Process
    {
        # Stop each Process
        ForEach ($Process in $Processes)
        {
            $ProcessName = $Process.ProcessName
            $TimeStamp = Get-Date -uformat "%T"
            Write-Output ("`r`n$TimeStamp`t${JobName}`nProcess:`t$ProcessName")
            $ProcessDetails = Get-Process -Name $ProcessName
            If ($ProcessDetails.Id -eq $null) { Write-Output "`t`t`tNothing to stop" }
            Else                              { Stop-Process -Id $ProcessDetails.Id }
            Start-Sleep -Seconds 10
        }

        # Stop each Service
        ForEach ($Service in $Services)
        {
            $ServiceArguments = "stop " + $Service.ServiceName
            $TimeStamp = Get-Date -uformat "%T"
            Write-Output ("`r`n$TimeStamp`t${JobName}`nCommand:`t$ServiceHandler`nArguments:`t$ServiceArguments")
			Launch-Process -ProcessHandler $ServiceHandler -ProcessArguments $ServiceArguments
            Start-Sleep -Seconds 10
        }

        # List all Packages
        $PackageArguments = "list -localonly"
        $TimeStamp = Get-Date -uformat "%T"
        Write-Output ("`r`n$TimeStamp`t${JobName}`nCommand:`t$PackageHandler`nArguments:`t$PackageArguments")
        Launch-Process -ProcessHandler $PackageHandler -ProcessArguments $PackageArguments
        Start-Sleep -Seconds 10

        # Upgrade all Packages
        $PackageArguments = "upgrade all --yes --no-progress"
        $TimeStamp = Get-Date -uformat "%T"
        Write-Output ("`r`n$TimeStamp`t${JobName}`nCommand:`t$PackageHandler`nArguments:`t$PackageArguments")
        Launch-Process -ProcessHandler $PackageHandler -ProcessArguments $PackageArguments
        Start-Sleep -Seconds 10

        # Start each Service
        ForEach ($Service in $Services)
        {
            $StartArguments = "start " + $Service.ServiceName
            $TimeStamp = Get-Date -uformat "%T"
            Write-Output ("`r`n$TimeStamp`t${JobName}`nCommand:`t$ServiceHandler`nArguments:`t$StartArguments")
            Launch-Process -ProcessHandler $ServiceHandler -ProcessArguments $StartArguments
            Start-Sleep -Seconds 10
        }
    }

    ## ---- [Function End] ----
    End {}
}


<#
.SYNOPSIS
    Automatically Upgrade Chocolatey Packages
.DESCRIPTION
    Stop any relevant services, then attempt to upgrade chocolatey packages
.EXAMPLE
    .\ChocoUpgrade.ps1
.NOTES
    Version:        1.0
    Author:         Dean Smith | deanwsmith@outlook.com
    Creation Date:  2019-07-16
    Purpose/Change: Initial script creation
#>

## ---- [Execution] ----

# Set the start date (which is today)
$DateStart = (Get-Date -Format "yyyy-MM-dd")

# Load configuration details and set up job and log details
$ConfigurationFile = ".\ChocoUpgrade.xml"
If (Test-Path $ConfigurationFile)
{
	Try
	{
        $Job = New-Object xml
        $Job.Load("$ConfigurationFile")
		$JobFolder = $Job.Configuration.JobFolder
		$JobName = $Job.Configuration.JobName
		$LogFolder = $Job.Configuration.LogFolder
        $JobDate = (Get-Date -Format FileDateTime)
        $LogFile = ("$LogFolder\${JobName}-$JobDate.log")
        $Processes = New-Object System.Collections.ArrayList
        ForEach ($ProcessName in $Job.Configuration.Processes.ProcessName)
        {
            $temp = "" | select "ProcessName"
            $temp.ProcessName = $ProcessName
            $Processes.Add($temp) | Out-Null
        }
        $Services = New-Object System.Collections.ArrayList
        ForEach ($ServiceName in $Job.Configuration.Services.ServiceName)
        {
            $temp = "" | select "ServiceName"
            $temp.ServiceName = $ServiceName
            $Services.Add($temp) | Out-Null
        }
        $PackageHandler = $Job.Configuration.PackageHandler
        $ServiceHandler = $Job.Configuration.ServiceHandler
	}
	Catch [system.exception]
    {
        Write-Output "Caught Exception: $($Error[0].Exception.Message)"
    }
}

# Start Transcript
Start-Transcript -Path $Logfile -NoClobber -Verbose -IncludeInvocationHeader
$Timestamp = Get-Date -UFormat "%T"
$LogMessage = ("-" * 79 + "`r`n$Timestamp`t${JobName}: Starting Transcript`r`n" + "-" * 79)
Write-Output $LogMessage

# Call function in order to upgrade chocolatey packages
Choco-Upgrade

## Stop Transcript
$Timestamp = Get-Date -UFormat "%T"
$LogMessage = ("`r`n" + "-" * 79 + "`r`n$Timestamp`t${JobName}: Stopping Transcript`r`n" + "-" * 79)
Write-Output $LogMessage
Stop-Transcript