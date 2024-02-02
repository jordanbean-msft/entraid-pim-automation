# EntraId-PIM-Automation

This repo shows how to run a PowerShell script inside an Azure Function for managing EntraID PIM groups.

## Disclaimer

**THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.**

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- Azure subscription & resource group

## How to use

1.  Deploy the code to Azure Functions

1.  Issue a POST command with a list of the groups to create/update

    ```bash
    POST http://localhost:7071/api/New-PIMEnabledGroup
    Content-Type: application/json    
    {
        "GroupNames": [
            "group1"
        ]
    }
    ```

## How to get valid values for PolicyRoleManagementPolicy Rule

1.  Import the Microsoft Graph cmdlet

    ```powershell
    Import-Module Microsoft.Graph
    ```

1.  Authenticate with the Microsoft Graph cmdlet

    ```powershell
    Connect-MgGraph
    ```

1.  Get the specific policy assignment for a group & role definition

    ```powershell
    $assignments = Get-MgPolicyRoleManagementPolicyAssignment -Filter "scopeId eq '$groupId' and scopeType eq 'Group' and roleDefinitionId eq 'member'"
    ```

1.  Get the list of policy rules available (17 predefined rules)

    ```powershell
    $policyRules = Get-MgPolicyRoleManagementPolicyRule -UnifiedRoleManagementPolicyId $assignments.PolicyId
    ```

1.  Print the definition of a specific rule (Expiration_Admin_Eligibility)

    ```powershell
    $policyRules | ? { $_.Id -eq 'Expiration_Admin_Eligibility' } | ConvertTo-Json
    ```

## Links

- https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-powershell?tabs=portal
- https://learn.microsoft.com/en-us/azure/azure-functions/create-first-function-vs-code-powershell
- https://learn.microsoft.com/en-us/powershell/microsoftgraph/get-started?view=graph-powershell-beta
- https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/concept-pim-for-groups
- https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/groups-role-settings#manage-role-settings-by-using-microsoft-graph
- https://learn.microsoft.com/en-us/powershell/microsoftgraph/how-to-manage-pim-policies?view=graph-powershell-1.0