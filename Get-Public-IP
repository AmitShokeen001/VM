<#
    .SYNOPSIS
        This script lists all virtual machines in each Azure subscription and displays their public IP addresses.
    
    .DESCRIPTION
        The script authenticates using Managed Identity, sets the context to a specified tenant, retrieves all subscriptions 
        in that tenant, and then lists all virtual machines in each subscription along with their public IP addresses if available.
    
    .NOTES
        Ensure that the Managed Identity has sufficient permissions to access subscriptions and resources.
        
    AUTHOR
       
        
    CREATED
        July 8th, 2024
    MODIFIED
        July 15th, 2024
    
    .LINK
      
#>

# Disable automatic saving of Azure context to disk within the current process.
# This prevents using outdated context data and improves script performance by reducing disk operations.
# The output is directed to Out-Null to suppress any console output from this command.
Disable-AzContextAutosave -Scope Process | Out-Null

try
{
    # Authenticate to Azure using Managed Identity
    $x = Connect-AzAccount -Identity
    Write-Output "Authenticated to Azure with $($x.Context.Account.Type): $($x.Context.Account.Id)"
    
    # Define the tenant ID to set the context to
    # (the below line needs to be modified to your environment)
    $tenantId = '12345678-1234-1234-1234-123456789abc'
    
    # Set the context to the specified tenant
    Set-AzContext -TenantId $tenantId | Out-Null
    Write-Output "Context set to Tenant Id: $tenantId"
    
    # Get all Azure subscriptions for the tenant
    $subs = Get-AzSubscription
    if ($subs.Count -eq 0)
    {
        Write-Output "No subscriptions found for tenant: $tenantId"
        exit
    }
    else
    {
        Write-Output "Retrieved $($subs.Count) subscriptions"
    }
    
    foreach ($sub in $subs)
    {
        Write-Output "======================================================================"
        Write-Output "Processing subscription: $($sub.Name) ($($sub.Id))"
        
        # Set the context to the current subscription
        Set-AzContext -Subscription $sub.Name | Out-Null
        Write-Output "Context set to subscription: $($sub.Name)"
        
        # Get all virtual machines in the subscription
        $vms = Get-AzVM
        Write-Output "Retrieved $(($vms).Count) virtual machines in subscription: $($sub.Name)"
        
        foreach ($vm in $vms)
        {
            Write-Output "----------------------------------------------------------------------"
            Write-Output "Processing VM: $($vm.Name) in Resource Group: $($vm.ResourceGroupName)"
            
            if ($vm.NetworkProfile.NetworkInterfaces.Count -gt 0)
            {
                $nicId = $vm.NetworkProfile.NetworkInterfaces[0].Id # Assuming only one NIC per VM
                Write-Output "Retrieving Network Interface: $nicId"
                $nic = Get-AzNetworkInterface -ResourceId $nicId
                
                if ($nic.IpConfigurations.PublicIpAddress -ne $null)
                {
                    $publicIpName = $nic.IpConfigurations.PublicIpAddress.Id.Split('/')[-1]
                    Write-Output "Attempting to retrieve Public IP Address: $publicIpName in Resource Group: $($vm.ResourceGroupName)"
                    
                    # Check if the public IP address exists before retrieving
                    $publicIp = Get-AzPublicIpAddress -ResourceGroupName $vm.ResourceGroupName -Name $publicIpName -ErrorAction SilentlyContinue
                    
                    if ($null -ne $publicIp) 
                    {
                        Write-Output "VM Name: $($vm.Name)"
                        Write-Output "Resource Group: $($vm.ResourceGroupName)"
                        Write-Output "Public IP Address: $($publicIp.IpAddress)"
                        Write-Output ""
                    }
                    else
                    {
                        Write-Output "Public IP Address: $publicIpName not found in Resource Group: $($vm.ResourceGroupName)"
                    }
                }
                else
                {
                    Write-Output "VM Name: $($vm.Name) in Resource Group: $($vm.ResourceGroupName) does not have a Public IP Address."
                }
            }
            else
            {
                Write-Output "VM Name: $($vm.Name) in Resource Group: $($vm.ResourceGroupName) does not have a Network Interface."
            }
        }
    }
}
catch
{
    Write-Output "An error occurred: $_"
}
<#
   
