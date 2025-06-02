#requires -version 4.0
#requires -module Hyper-V

Function Update-VMNote {
<#
.Synopsis
Update the Hyper-V VM Note with system information.
.Description
This command is designed to update a Hyper-V virtual machine note, for machines running Windows on a publically accessible network, with host information like this:
OperatingSystem : Microsoft Windows Server 2012 R2 Standard
ServicePack     :
PSVersion       : 4.0
Hostname        : CHI-FP03.GLOBOMANTICS.local
PSComputerName  : chi-fp03.globomantics.local
The command will make a PowerShell remoting connection to each virtual machine using the VM name as the computer name. If that is not the case, you can use the detected IP address and then connect to the resolved host name. Alternate credentials are supported for the remoting connection.
The default behavior is to append the information unless you use -Replace.
The default is all virtual machines on a given server, but you can specify an individual VM or use a wild card.
NOTE: You can only update virtual machines that are currently running.
.Parameter Credential
An alternate credential for the PowerShell remoting connection.
.Parameter ResolveIP
Normally, the command will use the VMName as the computername or you can use this parameter to resolve the computername from the first IPv4 address detected.
.Parameter Replace
The default behavior is to append the update. Use this parameter to replace the existing note.
.Notes
Last Updated: 11, January 2016
Version     : 1.1
Learn more about PowerShell:
http://jdhitsolutions.com/blog/essential-powershell-resources/
  ****************************************************************
  * DO NOT USE IN A PRODUCTION ENVIRONMENT UNTIL YOU HAVE TESTED *
  * THOROUGHLY IN A LAB ENVIRONMENT. USE AT YOUR OWN RISK.  IF   *
  * YOU DO NOT UNDERSTAND WHAT THIS SCRIPT DOES OR HOW IT WORKS, *
  * DO NOT USE IT OUTSIDE OF A SECURE, TEST SETTING.             *
  ****************************************************************
.Example
PS C:\> Update-VMNote -computername chi-hvr2 -credential globomantics\administrator 
Update all running virtual machines on server CHI-HVR2 using alternate credentials. The results will be appended to existing notes.
.Example
PS C:\> get-vm chi* -computername chi-hvr1 | update-vmnote -replace 
Get virtual machines that start with CHI* and replace their notes.
.Example
PS C:\> update-vmnote -vm chi-fp03 -computer chi-hvr1 -resolveIP -credential globomantics\administrator -passthru | format-list
Processing CHI-FP03
Name         : CHI-FP03
ComputerName : chi-hvr1
Notes        : OperatingSystem : Microsoft Windows Server 2012 R2 Standard
               ServicePack     :
               PSVersion       : 4.0
               Hostname        : CHI-FP03.GLOBOMANTICS.local
               PSComputerName  : chi-fp03.globomantics.local
Update the note for a single computer and pass the results to the pipeline.
#>

[cmdletbinding(SupportsShouldProcess)]
Param(
[Parameter(Position=0,ValueFromPipeline,ValueFromPipelineByPropertyName)]
[ValidateNotNullorEmpty()]
[Alias("name")]
[string]$VMName = "*",
[Alias("CN")]
[Parameter(ValueFromPipelineByPropertyName)]
[string]$Computername = $env:COMPUTERNAME,
[Alias("RunAs")]
[System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty,
[Switch]$ResolveIP,
[Switch]$Replace,
[Switch]$Passthru
)

Begin {
    Write-Verbose "Starting: $($MyInvocation.Mycommand)"
}

Process {
Write-Verbose "Getting running VMs from $($Computername.ToUpper())"

$VMs = (Get-VM -Name $VMName -computername $computername).Where({$_.state -eq 'running'})

if ($VMs) {
    foreach ($VM in $VMs) {
    Write-Host "Processing $($VM.Name)" -ForegroundColor Green
    if ($ResolveIP) {
        #get IP Address
        $IP = (Get-VMNetworkAdapter $VM).IPAddresses | where {$_ -match "\d{1,3}\." } | select -first 1

        #resolve IP address to name
        $named = (Resolve-DnsName -Name $IP).NameHost
    }
    else {
        #use VMname
        $named = $VM.name
    }
    
    #get PSVersion
    #get Operating System and service pack
    #resolving hostname locally using .NET because not all machines
    #may have proper cmdlets
    $sb = { 
        Get-WmiObject win32_Operatingsystem | 
        Select @{Name="OperatingSystem";Expression={$_.Caption}},
        @{Name="ServicePack";Expression={$_.CSDVersion}},
        @{Name="PSVersion";Expression= {$psversiontable.PSVersion}},
        @{Name="Hostname";Expression={
            If (Get-Command Resolve-DNSName -ErrorAction SilentlyContinue) {
            (Resolve-DnsName -Name $env:computername -Type A).Name
            }
            else {
        [system.net.dns]::Resolve($env:computername).hostname
        }
        }}
      } #close scriptblock
    
    #create a hashtable of parameters to splat to Invoke-Command
    $icmHash = @{
        ErrorAction = "Stop"
        Computername = $Named
        Scriptblock = $sb
    }
    
    #add credential if specified
    if ($Credential.username) {
        $icmHash.Add("Credential",$Credential)
    }
    Try {
        #run remoting command
        Write-Verbose "Getting remote information"
        $Info = Invoke-Command @icmHash  | Select * -ExcludeProperty RunspaceID
        #update Note
        Write-Verbose "`n$(($info | out-string).Trim())"
        if ($Replace) {
            Write-Verbose "Replacing VM Note"
            $newNote = ($info | out-string).Trim()
        }
        else {
            Write-Verbose "Appending VM Note"
            $current = $VM.Notes
            $newNote = $Current + "`n" + ($info | out-string).Trim()    
        }
        Set-VM $VM -Notes $newNote -Passthru:$passthru | Select Name,Computername,Notes
        #reset variable
        Remove-Variable Info
    } #try

    Catch {
        Write-Warning "[$($VM.Name)] Failed to get guest information. $($_.exception.message)"
    } #catch

    } #foreach VM
} #if running VMs found
else {
    Write-Warning "Failed to find any matching running virtual machines on $Computername"
}
} #process

End {
    Write-Verbose "Ending: $($MyInvocation.Mycommand)"
}

} #end function 

<#
Copyright (c) 2016 JDH Information Technology Solutions, Inc.
