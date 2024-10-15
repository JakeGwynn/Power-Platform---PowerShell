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

$tenantId = ""
$AppId = ""
$ClientSecret = ""

[System.Net.ServicePointManager]::SecurityProtocol = 'TLS12'

$TokenTimer = $null
$Token = $null

function Get-RestApiError ($RestError) {
    if ($RestError.Exception.GetType().FullName -eq "System.Net.WebException") {
        $ResponseStream = $null
        $Reader = $null
        $ResponseStream = $RestError.Exception.Response.GetResponseStream()
        $Reader = New-Object System.IO.StreamReader($ResponseStream)
        $Reader.BaseStream.Position = 0
        $Reader.DiscardBufferedData()
        return $Reader.ReadToEnd();
    }
}

function Get-MSToken ($TenantId, $AppId, $ClientSecret) {
    if($global:TokenTimer -eq $null -or $global:TokenTimer.elapsed.minutes -gt '55'){
        try{
            Write-Host "Authenticating to Graph API"
            $Body = @{    
                Grant_Type    = "client_credentials"
                Scope =  "https://service.powerapps.com/.default" # "https://service.flow.microsoft.com/.default"  
                client_Id     = $AppId
                Client_Secret = $ClientSecret
                } 
            $ConnectGraph = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Method POST -Body $Body
            $global:TokenTimer =  [system.diagnostics.stopwatch]::StartNew()	
            $global:GraphToken = $ConnectGraph.access_token
            return $ConnectGraph.access_token
        }
        catch {
            $RestError = $null
            $RestError = Get-RestApiError -RestError $_
            Write-Host $_ -ForegroundColor Red
            return Write-Host $RestError -ForegroundColor Red 
        }
    }
    else {
        return $global:GraphToken
    }
}

$Token = Get-MSToken -TenantId $TenantId -AppId $AppId -ClientSecret $ClientSecret

$headers = @{
    "Authorization" = "Bearer $Token"
    "Content-type" = "application/x-www-form-urlencoded"
}

# Get Environments
$envuri = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments?api-version=2024-05-01"

$environments = Invoke-RestMethod -Uri $envuri -Headers $headers -Method Get

$environments.value

# Get Flows
$uri = "https://api.flow.microsoft.com/providers/Microsoft.ProcessSimple/scopes/admin/environments/c06739f2-2f57-eff1-9d90-e8907bb6701c/v2/flows?api-version=2016-11-01"

$flows = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get

$flows.value.count

# Get Flow Run History
$uri = "https://api.flow.microsoft.com/providers/Microsoft.ProcessSimple/scopes/admin/environments/c06739f2-2f57-eff1-9d90-e8907bb6701c/flows/75c68bef-a922-dc1b-ebe3-1f5f4a014d98/runs?api-version=2023-06-01"

$flows = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get

# List of Flow runs
$flows.value

# List of Flow runs' metadata
$flows.value.properties
