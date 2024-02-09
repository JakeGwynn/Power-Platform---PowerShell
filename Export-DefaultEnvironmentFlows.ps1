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

# Run the following command a command prompt to install the PowerShell module
    # For system-wide installation, run the PowerShell command prompt as Administrator
        # Install-Module -Name Microsoft.PowerApps.Administration.PowerShell 
    # For installation without Administrator privileges, use the "-Scope CurrentUser" parameter
        # Install-Module -Name Microsoft.PowerApps.Administration.PowerShell -Scope CurrentUser

Import-Module Microsoft.PowerApps.Administration.PowerShell

# Connect to the Power Platform admin center
Add-PowerAppsAccount 

# Set the export path for the exported packages
$ExportPath = "c:\temp\DefaultEnvironmentFlowExport"
$NewOwnerObjectId = "54bb79ce-e9b3-471e-b2f9-9b80fec31256"

# Get the default environment
$DefaultEnvironment = Get-AdminPowerAppEnvironment -Default
$DefaultEnvironmentId = $DefaultEnvironment.EnvironmentName

# Get all flows in the default environment
$Flows = Get-AdminFlow -EnvironmentName $DefaultEnvironmentId

# API URL to export the package
$ApiUrl = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$DefaultEnvironmentId/exportPackage?api-version=2016-11-01"

# Create Generic List to store information about the exported packages
$ExportedPackages = New-Object System.Collections.Generic.List[psobject]

# Create the export path if it doesn't exist. Also remove any trailing backslashes.
$ExportPath = $ExportPath.TrimEnd("\")
if (!(Test-Path -Path $ExportPath)) {
    New-Item -Path $ExportPath -ItemType Directory
}

# Create a variable to replace invalid characters in the file name
$InvalidCharacters = [IO.Path]::GetInvalidFileNameChars() -join ''
$Replace = "[{0}]" -f [RegEx]::Escape($InvalidCharacters)


foreach ($Flow in $Flows) {
    $FlowId = $Flow.FlowName
    $FlowDisplayName = $Flow.DisplayName

    $FileName = ""
    $FileName = ($FlowDisplayName -replace $Replace) + "_" + ($FlowId -replace $Replace)

    $RequestBody = (ConvertFrom-Json @"
    {
        "includedResourceIds": [
            "/providers/Microsoft.Flow/flows/$FlowId"
        ],
        "details": {
            "displayName": "$FlowDisplayName",
            "description": "",
            "creator": "",
            "sourceEnvironment": ""
        },
        "resources": {
            "$FlowId=": {
                "id": "/providers/Microsoft.Flow/flows/$FlowId",
                "creationType": "Existing, New, Update",
                "suggestedCreationType": "New",
                "dependsOn": [],
                "details": {
                    "displayName": "$FlowDisplayName"
                },
                "name": "$FlowId",
                "type": "Microsoft.Flow/flows",
                "configurableBy": "User"
            }
        }
    }
"@)

#             "L1BST1ZJREVSUy9NSUNST1NPRlQuRkxPVy9GTE9XUy8zQ0YyREY0My00QTg2LTQzMUYtOTFFRi02REU4RjRCRDVCODE=": {
    Write-Host "`r`n"
    Write-Host "Exporting $FlowDisplayName"    
    $ApiRequest = $null
    $ApiRequest = InvokeApi -Method POST -Route $ApiUrl -Body $RequestBody

    if ($ApiRequest.status -eq "Failed" -and $ApiRequest.errors.code -eq "ConnectionAuthorizationFailed") {
        Write-Host "Error exporting $FlowDisplayName. Attempting to set new owner..." -ForegroundColor Red

        $SetNewOwner = Set-AdminFlowOwnerRole -EnvironmentName $DefaultEnvironmentId -FlowName $FlowId `
        -PrincipalObjectId $NewOwnerObjectId -Role "CanEdit" -PrincipalType "User" 
        
        if ($SetNewOwner.Code -eq "200") {
            Write-Host "New owner set for $FlowDisplayName. Retrying export..." -ForegroundColor Green
            $ApiRequest = InvokeApi -Method POST -Route $ApiUrl -Body $RequestBody
        } else {
            Write-Host "Error setting new owner for $FlowDisplayName" -ForegroundColor Red
            $SetNewOwner | fl
        }
    }
    if ($ApiRequest.status -eq "Failed") {
        Write-Host "Error exporting $FlowDisplayName" -ForegroundColor Red
        $ApiRequest | fl
    } elseif ($ApiRequest.status -eq "Succeeded") {
        Write-Host "Exported $FlowDisplayName successfully. Downloading package..." -ForegroundColor Green
        Invoke-RestMethod -Uri $ApiRequest.packageLink.value -OutFile "$ExportPath\$FileName.zip"
    } else {
        Write-Host "Unknown status for $FlowDisplayName" -ForegroundColor Red
        $ApiRequest | fl
    }

    $ExportedPackages.Add([pscustomobject]@{
        FlowDisplayName = $FlowDisplayName
        FlowId = $FlowId
        ExportStatus = $ApiRequest.status
        ExportedPackageLink = $ApiRequest.packageLink.value
        ErrorCode = $ApiRequest.errors.code
        ErrorMessage = $ApiRequest.errors.message
    })
}

$ExportedPackages | Export-Csv -Path "$ExportPath\ExportedPackages.csv" -NoTypeInformation
