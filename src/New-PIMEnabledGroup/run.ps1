using namespace System.Net

param($Request, $TriggerMetadata)

Set-StrictMode -Version Latest

Import-Module ActionsModule

try {
    $tenantId, $clientID, $clientSecret = Get-EnvironmentVariables
    
    $token = Get-MgAccessToken -TenantID $tenantId `
                            -ClientID $clientID `
                            -ClientSecret $clientSecret

    Write-Debug "Connecting to Microsoft Graph API"

    Connect-MgGraph -AccessToken $Token | Out-Null

    Write-Debug "Connected to Microsoft Graph API"

    $groups = $Request.Body.Groups
    $groupIds = @()

    foreach($group in $groups) {
        $groupId = Set-EntraIdGroup -DisplayName $group
        Set-EntraIdPim -GroupId $groupId
        $groupIds += $groupId
    }
}
catch {
    Write-Error $_.Exception.Message

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::BadRequest
        Body = @{
            Error = $_.Exception.Message
        }
    })
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = @{
        GroupIds = $groupIds
    }
})
