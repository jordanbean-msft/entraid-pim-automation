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

    $groupNames = $Request.Body.GroupNames
    $groupIds = @()

    foreach($groupName in $groupNames) {
        $groupId = Set-EntraIdGroup -DisplayName $groupName
        Set-EntraIdPim -GroupId $groupId
        Set-EntraIdAccessReview -GroupId $groupId
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

    return
}

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = @{
        GroupIds = $groupIds
    }
})
