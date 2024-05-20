# Location of CSV File
$CSVFile = "C:\Users\jakegwynn\Downloads\PPUsageReport.csv"

# Install Microsoft Graph PowerShell module if not alreay installed
if (-not (Get-installedModule -Name "Microsoft.Graph")) {
    Install-Module -Name "Microsoft.Graph" -Force -AllowClobber -Scope CurrentUser
} else {
    Import-module -Name "Microsoft.Graph"
}

Connect-MgGraph

# Get the list of users
$Users = Get-MgUser -All

# Get the list of users with their usage report
$UsageReport = Import-Csv -Path $CSVFile

foreach ($Row in $UsageReport) {
    $User = $Users | Where-Object { $_.Id -eq $Row.'Caller ID' }
    $User.UserPrincipalName
    if ($User) {
        $Row | Add-Member -MemberType NoteProperty -Name "User DisplayName" -Value $User.DisplayName
        $Row | Add-Member -MemberType NoteProperty -Name "User UPN" -Value $User.UserPrincipalName
    }
}

$UsageReport | Export-Csv -Path $CSVFile -NoTypeInformation