#Requires -RunAsAdministrator
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

#########################################################################################

$currentPolicy = "A sufficient password history is being kept"
$checkEnforcePasswordHistory = Prompt-Policy -policyName $currentPolicy

if ($checkEnforcePasswordHistory -eq 0) {
    # Informing the user
    Write-Host "`n`t[!] Checking '$currentPolicy'"

    # Creating the temporary file for security stuff
    $tempFile = "$env:TEMP\secpolicy.inf"
    secedit /export /cfg $tempFile /areas SECURITYPOLICY | Out-Null

    # Find the policy line
    $policyLine = Get-Content $tempFile | Select-String "PasswordHistorySize"

    # Get the value from the line
    $value = [int](($policyLine -split "=")[1].Trim())

    # Get rid of the temp file
    Remove-Item $tempFile

    # If the value is 5 or greater, tell that to the user. Otherwise, tell the user the value and ask if they want it changed to 5.
    if ($value -ge 5) {
        Write-Host "`n`t`t$value passwords are remembered."
    } else {
        Write-Host "`n`t`t$value password(s) are remembered. Changing this to 5..."

        # Create the configuration string
        $config = @"
[Unicode]
Unicode=yes
[System Access]
PasswordHistorySize = 5
[Version]
signature="`$CHICAGO`$"
Revision=1        
"@

        # Save the text into a temp file
        $importFile = "$env:TEMP\secupdate.inf"
        $config | Out-File -Filepath $importFile -Encoding ascii

        # import this into the Windows Security Database
        secedit /configure /db $env:windir\security\local.sdb /cfg $importFile /areas SECURITYPOLICY | Out-Null

        # Remove the temp file as it is not needed anymore
        Remove-Item $importFile

        # Force systemwide updates
        gpupdate /force | Out-Null

        Write-Host "`n`n`t`t[!] Changed policy to 5 passwords remembered."
    }
} else {
    Write-Host "`n`t[!] Skipping '$currentPolicy'"
}

$currentPolicy = "Everyone may not access this computer from the network"
$checkAccessThisComputerFromTheNetwork = Prompt-Policy -policyName $currentPolicy

if ($checkAccessThisComputerFromTheNetwork -eq 0) {
    Write-Host "`n`t[!] Checking '$currentPolicy'"
} else {
    Write-Host "`n`t[!] Skipping '$currentPolicy'"
}