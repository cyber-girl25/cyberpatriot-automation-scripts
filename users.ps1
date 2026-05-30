function Prompt-Policy {
    param(
        $policyName
    )
    # Defining title and message
    $title = "[*] " + $policyName
    $message = "Would you like to check the policy '$policyName'?"

    # Defining options
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Check ""$policyName"""
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Skip ""$policyName"""
    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

    # Presenting the choice to the user, yes is default
    # Note to self: 0 means yes, 1 means no
    $result = $host.ui.PromptForChoice($title, $message, $options, 0)

    # Returning the result
    return $result
}

function Prompt-User {
    param(
        $userName,
        $action
    )
    # Defining title and message
    $title = "[*] " + $userName
    $message = $action

    # Defining options
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Check ""$policyName"""
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Skip ""$policyName"""
    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

    # Presenting the choice to the user, yes is default
    # Note to self: 0 means yes, 1 means no
    $result = $host.ui.PromptForChoice($title, $message, $options, 0)

    # Returning the result
    return $result
}

#########################################################################################

$currentPolicy = "Remove unauthorized users"
$checkUnauthorizedUsers = Prompt-Policy -policyName $currentPolicy

if ($checkUnauthorizedUsers -eq 0) {
    # Get list of authorized users
    $prompt = @"

    Enter the authorized users list. Separate with commas.
    Example: alice,bob,charlie,jane
    Users
"@

    $authorizedUsers = @((Read-Host $prompt) -split ",")

    # Get list of all users
    $currentUsers = @((Get-LocalUser).Name)

    # Default users
    $defaults = @("Administrator", "Guest", "DefaultAccount", "WDAGUtilityAccount")

    # Inform the user
    Write-Host "`n`t[!] Checking '$currentPolicy'"

    # Loop through each current user. If it isn't a default user, check if it's in authorized users. If it isn't, ask the user if it should be removed. If yes, remove it.
    foreach ($currentUser in $currentUsers) {
        if ($defaults -notcontains $currentUser) {
            if ($authorizedUsers -notcontains $currentUser) {
                $deleteUser = Prompt-User -userName $currentUser -action "User '$currentUser' is not in the provided list of authorized users. Would you like to delete them?"
                if ($deleteUser -eq 0) {
                    Write-Host "`n`t`tRemoving user '$currentUser'..."

                    # Remove user
                    Remove-LocalUser -Name $currentUser

                    Write-Host "`n`t`t[!] Removed user '$currentUser'"
                } else {
                    Write-Host "`n`t`tIgnoring user '$currentUser'..."
                }
            }
        }
    }
    Write-Host "`n`t`t`t[!] Checked all users"
} else {
    Write-Host "`n`t[!] Skipping '$currentPolicy'"
}

#########################################################################################

$currentPolicy = "Add new users"
$doAddUsers = Prompt-Policy -policyName $currentPolicy

if ($doAddUsers -eq 0) {
    Write-Host "`n`t[!] Checking '$currentPolicy'"
    # Get list of users to add
    $prompt = @"

    Enter the list of users to make accounts for. Separate with commas.
    Example: carlisle,burma,emma
    New users
"@
    $usersToAdd = @((Read-Host $prompt) -split ",")

    # Get the secure password
    $prompt = @"

    Enter the secure password. If none is provided, the default 'CyberPatriot123!' will be used.
    Password
"@
    $password = Read-Host $prompt -AsSecureString

    if ($password -eq "") {
        $passwordText = "CyberPatriot123!"
        $password = ConvertTo-SecureString $passwordText -AsPlainText -Force
    }

    foreach ($user in $usersToAdd) {
            New-LocalUser -Name $user -Password $password | Out-Null
            Write-Host "`n`t`t[!] Added user '$user'"
        }
    Write-Host "`n`t`t[!] Added all users"
} else {
    Write-Host "`n`t[!] Skipping '$currentPolicy'"
}