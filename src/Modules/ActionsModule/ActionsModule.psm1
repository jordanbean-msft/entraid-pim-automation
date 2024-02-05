$groupDisplayNameSuffix = "_PIM"

<#
.SYNOPSIS
    Creates a new group in Entra ID if it doesn't exist
.PARAMETER displayName
    The display name of the group to create
.OUTPUTS
    The group id of the created or existing group
#>
function Set-EntraIdGroup([string]$displayName) {
    $group = Get-MgGroup -Filter "displayName eq '$displayName'"

    if (!$group) {
        Write-Debug "Creating group $displayName + $groupDisplayNameSuffix..."

        try {
            $group = New-MgGroup -DisplayName $displayName + $groupDisplayNameSuffix `
                -MailEnabled $false `
                -SecurityEnabled $true `
                -Owners [] `
                -IsAssignableToRole $false
        }
        catch {
            Write-Error "Failed to create group $displayName + $groupDisplayNameSuffix : $_"
            throw
        }

        Write-Debug "Created group $displayName + $groupDisplayNameSuffix"
    }

    return $group.Id
}

<#
.SYNOPSIS
    Gets the array of EntraID Policy Role Management Policy Rules to apply
.OUTPUTS
    The array of policy rules
#>
function Get-EntraIdPolicyRoleManagementPolicyRules() {
    $policyRules = @(
        [Microsoft.Graph.PowerShell.Models.IMicrosoftGraphUnifiedRoleManagementPolicyRule]@{
            "@odata.type"        = "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule"
            Id                   = "Expiration_EndUser_Assignment"
            isExpirationRequired = $false
            maximumDuration      = "PT8H"
            Target               = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                Caller              = "EndUser"
                Operations          = @(
                    "all"
                )
                Level               = "Assignment"
                InheritableSettings = @(
                )
                EnforcedSettings    = @(
                )
            }
        }
        [Microsoft.Graph.PowerShell.Models.IMicrosoftGraphUnifiedRoleManagementPolicyRule]@{
            "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyEnablementRule"
            Id            = "Enablement_EndUser_Assignment"
            EnabledRules  = @("MultiFactorAuthentication")
            Target        = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                Caller              = "EndUser"
                Operations          = @(
                    "all"
                )
                Level               = "Assignment"
                InheritableSettings = @(
                )
                EnforcedSettings    = @(
                )
            }
        }
    )

    return $policyRules
}


<#
.SYNOPSIS
    Updates the policy for the member role in Entra ID
.PARAMETER memberPolicyId
    The id of the policy to update
#>
function Set-EntraIdPolicyRoleManagementPolicy([string]$memberPolicyId) {
    $policyRules = Get-EntraIdPolicyRoleManagementPolicyRules

    foreach ($policyRule in $policyRules) {
        Write-Debug "Updating policy rule $($policyRule.Id)..."

        try {
            Update-MgPolicyRoleManagementPolicyRule -UnifiedRoleManagementPolicyId $memberPolicyId `
                -UnifiedRoleManagementPolicyRuleId $policyRule.Id `
                -BodyParameter $policyRule `
                -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to update policy rule $($policyRule.Id): $_"
            throw
        }
        
        Write-Debug "Updated policy rule $($policyRule.Id)"
    }
}

<#
.SYNOPSIS
    Sets the PIM policy for a group in Entra ID
.PARAMETER groupId
    The id of the group to set the PIM policy for
#>
function Set-EntraIdPim([string]$groupId) {
    $group = Get-MgGroup -Filter "id eq '$groupId'"

    if (!$group) {
        Write-Error "Group $groupId not found"
        throw
    }

    #get the specific policy for the member role, not the owner role
    $memberPolicyId = Get-MgPolicyRoleManagementPolicyAssignment -Filter "scopeId eq '$($group.Id)' and scopeType eq 'Group' and roleDefinitionId eq 'member'"

    if (!$memberPolicyId) {
        Write-Error "Policy for member role not found for group $($group.Id)"
        throw
    }

    Set-EntraIdPolicyRoleManagementPolicy -MemberPolicyId $memberPolicyId.PolicyId
}

<#
.SYNOPSIS
    Sets the access review for a group in Entra ID
.PARAMETER groupId
    The id of the group to set the access review for
#>
function Set-EntraIdAccessReview([string]$groupId) {
    $group = Get-MgGroup -Filter "id eq '$groupId'"

    if (!$group) {
        Write-Error "Group $groupId not found"
        throw
    }

    $bodyParameter = @{
        displayName              = "Annual_AppEntitlement_AccessReview - $($group.DisplayName)"
        descriptionForAdmins     = "Typically used to assign access or role inside an Azure Application"
        descriptionForReviewers  = "Typically used to assign access or role inside an Azure Application"
        scope                    = @{
            query     = "/groups/$($group.Id)/members"
            queryType = "MicrosoftGraph"
        }
        instanceEnumerationScope = @{
            query     = "/groups/$($group.Id)"
            queryType = "MicrosoftGraph"
        }
        settings                 = @{
            mailNotificationsEnabled        = $true
            reminderNotificationsEnabled    = $true
            justificationRequiredOnApproval = $false
            defaultDecisionEnabled          = $true
            defaultDecision                 = "Deny"
            instanceDurationInDays          = 14
            autoApplyDecisionsEnabled       = $true
            recommendationsEnabled          = $true
            recurrence                      = @{
                pattern = $null
                range   = @{
                    type                = "numbered"
                    numberOfOccurrences = 0
                    recurrenceTimeZone  = $null
                    startDate           = "2022-02-11"
                    endDate             = $null
                }
            }
        }
    }   

    try {
        New-MgIdentityGovernanceAccessReviewDefinition -BodyParameter $bodyParameter `
            -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Error "Failed to create access review for group $($group.Id): $_"
        throw
    }
}

<#
.SYNOPSIS
    Gets the environment variables
.OUTPUTS
    The environment variables as a hashtable (TenantID, ClientID, ClientSecret)
#>
function Get-EnvironmentVariables() {
    $tenantID = $env:TENANT_ID

    if (!$tenantID) {
        Write-Error "TENANT_ID environment variable is not set"
        throw
    }

    $clientID = $env:CLIENT_ID

    if (!$clientID) {
        Write-Error "CLIENT_ID environment variable is not set"
        throw
    }

    $clientSecret = $env:CLIENT_SECRET

    if (!$clientSecret) {
        Write-Error "CLIENT_SECRET environment variable is not set"
        throw
    }

    return $tenantID, $clientID, $clientSecret
}

<#
.SYNOPSIS
    Gets an access token for the Microsoft Graph API
.PARAMETER tenantID
    The tenant id
.PARAMETER clientID
    The client id
.PARAMETER clientSecret
    The client secret
.OUTPUTS
    The access token
#>
function Get-MgAccessToken([string]$tenantID, [string]$clientID, [string]$clientSecret) {
    $body = @{
        Grant_Type    = "client_credentials"
        Scope         = "https://graph.microsoft.com/.default"
        Client_Id     = $clientID
        Client_Secret = $clientSecret
    }

    Write-Debug "Getting access token"
        
    $connection = Invoke-RestMethod `
        -Uri "https://login.microsoftonline.com/$tenantID/oauth2/v2.0/token" `
        -Method POST `
        -Body $body

    Write-Debug "Got access token"
    
    $token = $connection.access_token

    return $token
}

Export-ModuleMember -Function Set-EntraIdGroup
Export-ModuleMember -Function Set-EntraIdPim
Export-ModuleMember -Function Get-EnvironmentVariables
Export-ModuleMember -Function Get-MgAccessToken
Export-ModuleMember -Function Set-EntraIdAccessReview