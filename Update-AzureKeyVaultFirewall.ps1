<#
Copyright 2024 Jake Gwynn

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), 
to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, 
and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#>

# Connect to Azure using Azure PowerShell module
Connect-AzAccount

# Define the Key Vault name and resource group
$KeyVaultName = "KeyVault1-JakeGwynnDemo"
$ResourceGroupName = "PnP-Site-Provisioning"

$AzurePublicIPAddressPageRequest = Invoke-WebRequest -Uri 'https://www.microsoft.com/en-gb/download/confirmation.aspx?id=56519'

$JSONFileLink = (($AzurePublicIPAddressPageRequest.Links |  Where-Object { $_.href -like "*Public*json" })[0].href)

$JSONFileRequest = Invoke-WebRequest -Uri $JSONFileLink -ContentType 'application/json'

$JSONFileContent = [System.Text.Encoding]::UTF8.GetString($JSONFileRequest.Content)

# Convert the string from JSON to a PowerShell object
$AllIpAddressesObject = $JSONFileContent | ConvertFrom-Json

# Get the IP addresses from the JSON object for the following names: AzureConnectors.NorthCentralUS, AzureConnectors.SouthCentralUS, AzureConnectors.CentralUS, AzureConnectors.EastUS, AzureConnectors.EastUS2, AzureConnectors.WestUS, AzureConnectors.WestUS2, AzureConnectors.WestUS3, AzureConnectors.WestCentralUS, AzureConnectors.WestUS2, AzureConnectors.WestCentralUS
$PowerPlatIPAddressesObject = $AllIpAddressesObject.values | Where-Object { $_.name -in @("AzureConnectors.NorthCentralUS", "AzureConnectors.SouthCentralUS", "AzureConnectors.CentralUS", "AzureConnectors.EastUS", "AzureConnectors.EastUS2", "AzureConnectors.WestUS", "AzureConnectors.WestUS2", "AzureConnectors.WestUS3", "AzureConnectors.WestCentralUS", "AzureConnectors.WestUS2", "AzureConnectors.WestCentralUS") }

# Take the following list of IP addresses and make it an array that will work to input to an azure storage account firewall rule
$PowerPlatIPAddresses = $PowerPlatIPAddressesObject | Select-Object -ExpandProperty properties | Select-Object -ExpandProperty addressPrefixes

foreach ($IP in $PowerPlatIPAddresses) {
    Add-AzKeyVaultNetworkRule -VaultName $KeyVaultName -ResourceGroupName $ResourceGroupName -IPAddressRange $IP
}