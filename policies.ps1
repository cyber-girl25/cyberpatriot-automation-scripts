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

function Get-SeceditPolicy {
    param(
        $area,
        $policyName
    )
    # Creating the temporary file for security stuff
    $tempFile = "$env:TEMP\secpolicy.inf"
    secedit /export /cfg $tempFile /areas $area | Out-Null

    # Find the policy line
    $policyLine = Get-Content $tempFile | Select-String -Pattern $policyName -SimpleMatch

    # Get rid of the temp file
    Remove-Item $tempFile

    # Return the policy
    return $policyLine
}

function Write-SeceditPolicy {
    param(
        $area,
        $policyHeader,
        $policyLine
    )
    # Create the configuration string
        $config = @"
[Unicode]
Unicode=yes
[$policyHeader]
$policyLine
[Version]
signature="`$CHICAGO`$"
Revision=1        
"@

        # Save the text into a temp file
        $importFile = "$env:TEMP\secupdate.inf"
        $config | Out-File -Filepath $importFile -Encoding ascii

        # import this into the Windows Security Database
        secedit /configure /db $env:windir\security\local.sdb /cfg $importFile /areas $area | Out-Null

        # Remove the temp file as it is not needed anymore
        Remove-Item $importFile

        # Force systemwide updates
        gpupdate /force | Out-Null
}

#########################################################################################

$currentPolicy = "A sufficient password history is being kept"
$checkEnforcePasswordHistory = Prompt-Policy -policyName $currentPolicy

if ($checkEnforcePasswordHistory -eq 0) {
    # Informing the user
    Write-Host "`n`t[!] Checking '$currentPolicy'"

    # Get policy line
    $policyLine = Get-SeceditPolicy -area SECURITYPOLICY -policyName PasswordHistorySize

    # Get the value from the line
    $value = [int](($policyLine -split "=")[1].Trim())

    # If the value is 5 or greater, tell that to the user. Otherwise, tell the user the value and ask if they want it changed to 5.
    if ($value -ge 5) {
        Write-Host "`n`t`t$value passwords are remembered."
    } else {
        Write-Host "`n`t`t$value password(s) are remembered. Changing this to 5..."

        # Write the policy
        Write-SeceditPolicy -area "SECURITYPOLICY" -policyHeader "System Access" -policyLine "PasswordHistorySize = 5"

        Write-Host "`n`n`t`t[!] Changed policy to 5 passwords remembered."
    }
} else {
    Write-Host "`n`t[!] Skipping '$currentPolicy'"
}

#########################################################################################

$currentPolicy = "Everyone may not access this computer from the network"
$checkAccessThisComputerFromTheNetwork = Prompt-Policy -policyName $currentPolicy

if ($checkAccessThisComputerFromTheNetwork -eq 0) {
    Write-Host "`n`t[!] Checking '$currentPolicy'"

    # Get the policy line
    $policyLine = Get-SeceditPolicy -area "USER_RIGHTS" -policyName "SeNetworkLogonRight"

    # Get the values
    $values = (($policyLine -split "=")[1].Trim() -split ",")
    # If everyone is in the values, remove it.
    if ("*S-1-1-0" -in $values) {
        Write-Host "`n`t`tThe group Everyone can access this computer from the network. Removing..."

        # Determine the new value
        $newValues = ($values -ne "*S-1-1-0") -join ","
        $newPolicy = "SeNetworkLogonRight = $newValues"
        
        # Write the policy
        Write-SeceditPolicy -area "USER_RIGHTS" -policyHeader "Privilege Rights" -policyLine $newPolicy

        Write-Host "`n`n`t`t[!] Removed Everyone from policy."
    } else {
        Write-Host "`n`t`tThe group Everyone cannot access this computer from the network."
    }
} else {
    Write-Host "`n`t[!] Skipping '$currentPolicy'"
}

#########################################################################################

$currentPolicy = "Let Everyone permissions apply to anonymous users [disabled]"
$checkLetEveryonePermsApplyToAnonUsers = Prompt-Policy -policyName $currentPolicy

if ($checkLetEveryonePermsApplyToAnonUsers -eq 0) {
    Write-Host "`n`t[!] Checking '$currentPolicy'"

    # Get registry value
    $everyoneIncludesAnon = (Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Lsa").EveryoneIncludesAnonymous

    # If it is disabled, inform the user. Else, inform, change the value, inform again.
    if ($everyoneIncludesAnon -eq 0) {
        Write-Host "`n`t`tLet Everyone permissions apply to anonymous users is Disabled"
    } else {
        Write-Host "`n`t`tLet Everyone permissions apply to anonymous users is Enabled. Disabling..."

        # Change value of key to 0
        Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Lsa" -Name "EveryoneIncludesAnonymous" -Value 0

        # Force systemwide updates
        gpupdate /force | Out-Null
    }
} else {
    Write-Host "`n`t[!] Skipping '$currentPolicy"
}

#########################################################################################

$currentPolicy = "A secure minimum password length is required"
$checkSecureMinPWrequired = Prompt-Policy -policyName $currentPolicy
if ($checkSecureMinPWrequired -eq 0) {
    Write-Host "`n`t[!] Checking '$currentPolicy'"

    # Get policy line
    $policyLine = Get-SeceditPolicy -area "SECURITYPOLICY" -policyName "MinimumPasswordLength"
    
    # Get value
    $value = [int]($policyLine -split "=")[1].Trim()

    if ($value -ge 10) {
        Write-Host "`n`t`tThe minimum password length is $value"
    } else {
        Write-Host "`n`t`tThe minimum password length is $value. Changing this to 10..."

        # Determine new policy line
        $newPolicy = "MinimumPasswordLength = 10"
        
        # Write the policy
        Write-SeceditPolicy -area "SECURITYPOLICY" -policyHeader "System Access" -policyLine $newPolicy

        Write-Host "`n`n`t`t[!] Changed minimum password length to 10 characters."
    }
} else {
    Write-Host "`n`t[!] Skipping '$currentPolicy'"
}

#########################################################################################

$currentPolicy = "A secure maximum password age exists"
$checkSecureMaxPWAgeExists = Prompt-Policy -policyName $currentPolicy
if ($checkSecureMaxPWAgeExists -eq 0) {
    Write-Host "`n`t[!] Checking '$currentPolicy'"

    # Get policy line
    $policyLine = Get-SeceditPolicy -area "SECURITYPOLICY" -policyName "MaximumPasswordAge"
    
    # Get value
    $value = [int]($policyLine -split "=")[1].Trim()

    if (($value -le 90) -and ($value -ge 1)) {
        Write-Host "`n`t`tThe maximum password age is $value"
    } else {
        Write-Host "`n`t`tThe maximum password age is $value. Changing this to 90..."

        # Determine new policy line
        $newPolicy = "MaximumPasswordAge = 90"
        
        # Write the policy
        Write-SeceditPolicy -area "SECURITYPOLICY" -policyHeader "System Access" -policyLine $newPolicy

        Write-Host "`n`n`t`t[!] Changed maximum password age to 90."
    }
} else {
    Write-Host "`n`t[!] Skipping '$currentPolicy'"
}

#########################################################################################

$currentPolicy = "A secure lockout threshold exists"
$checkSecureMaxPWAgeExists = Prompt-Policy -policyName $currentPolicy
if ($checkSecureMaxPWAgeExists -eq 0) {
    Write-Host "`n`t[!] Checking '$currentPolicy'"

    # Get policy line
    $policyLine = Get-SeceditPolicy -area "SECURITYPOLICY" -policyName "LockoutBadCount"
    
    # Get value
    $value = [int]($policyLine -split "=")[1].Trim()

    if ($value -eq 10) {
        Write-Host "`n`t`tThe lockout threshold is $value"
    } else {
        Write-Host "`n`t`tThe lockout threshold is $value. Changing this to 10..."

        # Determine new policy line
        $newPolicy = "LockoutBadCount = 10"
        
        # Write the policy
        Write-SeceditPolicy -area "SECURITYPOLICY" -policyHeader "System Access" -policyLine $newPolicy

        Write-Host "`n`n`t`t[!] Changed lockout threshold age to 10."
    }
} else {
    Write-Host "`n`t[!] Skipping '$currentPolicy'"
}

#########################################################################################

$currentPolicy = "Passwords must meet complexity requirements"
$checkPWMeetComplexityReqs = Prompt-Policy -policyName $currentPolicy
if ($checkPWMeetComplexityReqs -eq 0) {
    Write-Host "`n`t[!] Checking '$currentPolicy'"

    # Get policy line
    $policyLine = Get-SeceditPolicy -area "SECURITYPOLICY" -policyName "PasswordComplexity"
    
    # Get value
    $value = [int]($policyLine -split "=")[1].Trim()

    if ($value -eq 1) {
        Write-Host "`n`t`tThe policy is enabled."
    } else {
        Write-Host "`n`t`tThe policy is disabled. Enabling..."

        # Determine new policy line
        $newPolicy = "PasswordComplexity = 1"
        
        # Write the policy
        Write-SeceditPolicy -area "SECURITYPOLICY" -policyHeader "System Access" -policyLine $newPolicy

        Write-Host "`n`n`t`t[!] Enabled policy."
    }
} else {
    Write-Host "`n`t[!] Skipping '$currentPolicy'"
}

#########################################################################################

$currentPolicy = "Behavior of the elevation prompt for administrators in Admin Approval Mode configured to prompt"
$checkElevationPromptPolicy = Prompt-Policy -policyName $currentPolicy
if ($checkElevationPromptPolicy -eq 0) {
    Write-Host "`n`t[!] Checking '$currentPolicy'"

    # Get policy line
    $policyLine = Get-SeceditPolicy -area "SECURITYPOLICY" -policyName "MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\System\ConsentPromptBehaviorAdmin"
    
    # Get value
    $value = ($policyLine -split "=")[1]

    if ($value -eq "4,2") {
        Write-Host "`n`t`tThe policy prompts for consent on the secure desktop."
    } else {
        Write-Host "`n`t`tThe policy does not prompt for consent on the secure desktop. Correcting this..."

        # Determine new policy line
        $newPolicy = "MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\System\ConsentPromptBehaviorAdmin=4,2"
        
        # Write the policy
        Write-SeceditPolicy -area "SECURITYPOLICY" -policyHeader "Registry Values" -policyLine $newPolicy

        Write-Host "`n`n`t`t[!] Corrected policy to prompting for consent on the secure desktop."
    }
} else {
    Write-Host "`n`t[!] Skipping '$currentPolicy'"
}

#########################################################################################

$currentPolicy = "Limit local use of blank passwords to console only [enabled]"
$checkElevationPromptPolicy = Prompt-Policy -policyName $currentPolicy
if ($checkElevationPromptPolicy -eq 0) {
    Write-Host "`n`t[!] Checking '$currentPolicy'"

    # Get policy line
    $policyLine = Get-SeceditPolicy -area "SECURITYPOLICY" -policyName "MACHINE\System\CurrentControlSet\Control\Lsa\LimitBlankPasswordUse"
    
    # Get value
    $value = ($policyLine -split "=")[1]

    if ($value -eq "4,1") {
        Write-Host "`n`t`tThe policy limits local use of blank passwords to console only."
    } else {
        Write-Host "`n`t`tThe policy does not limit local use of blank passwords to console only. Correcting this..."

        # Determine new policy line
        $newPolicy = "MACHINE\System\CurrentControlSet\Control\Lsa\LimitBlankPasswordUse=4,1"
        
        # Write the policy
        Write-SeceditPolicy -area "SECURITYPOLICY" -policyHeader "Registry Values" -policyLine $newPolicy

        Write-Host "`n`n`t`t[!] Corrected policy to limiting local use of blank passwords to console only."
    }
} else {
    Write-Host "`n`t[!] Skipping '$currentPolicy'"
}

#########################################################################################

$currentPolicy = "Do not allow anonymous enumeration of SAM accounts [enabled]"
$checkElevationPromptPolicy = Prompt-Policy -policyName $currentPolicy
if ($checkElevationPromptPolicy -eq 0) {
    Write-Host "`n`t[!] Checking '$currentPolicy'"

    # Get policy line
    $policyLine = Get-SeceditPolicy -area "SECURITYPOLICY" -policyName "MACHINE\System\CurrentControlSet\Control\Lsa\RestrictAnonymousSAM"
    
    # Get value
    $value = ($policyLine -split "=")[1]

    if ($value -eq "4,1") {
        Write-Host "`n`t`tThe policy does not allow anonymous enumeration of SAM accounts."
    } else {
        Write-Host "`n`t`tThe policy allows anonymous enumeration of SAM accounts. Correcting this..."

        # Determine new policy line
        $newPolicy = "MACHINE\System\CurrentControlSet\Control\Lsa\RestrictAnonymousSAM=4,1"
        
        # Write the policy
        Write-SeceditPolicy -area "SECURITYPOLICY" -policyHeader "Registry Values" -policyLine $newPolicy

        Write-Host "`n`n`t`t[!] Corrected policy to not allowing anonymous enumeration of SAM accounts."
    }
} else {
    Write-Host "`n`t[!] Skipping '$currentPolicy'"
}

#########################################################################################

$currentPolicy = "Users may not change the system time"
$checkAccessThisComputerFromTheNetwork = Prompt-Policy -policyName $currentPolicy

if ($checkAccessThisComputerFromTheNetwork -eq 0) {
    Write-Host "`n`t[!] Checking '$currentPolicy'"

    # Get the policy line
    $policyLine = Get-SeceditPolicy -area "USER_RIGHTS" -policyName "SeSystemtimePrivilege"

    # Get the values
    $values = (($policyLine -split "=")[1].Trim() -split ",")
    # If everyone is in the values, remove it.
    if ("*S-1-5-32-545" -in $values) {
        Write-Host "`n`t`tThe group Users can change the system time. Removing..."

        # Determine the new value
        $newValues = ($values -ne "*S-1-5-32-545") -join ","
        $newPolicy = "SeSystemtimePrivilege = $newValues"
        
        # Write the policy
        Write-SeceditPolicy -area "USER_RIGHTS" -policyHeader "Privilege Rights" -policyLine $newPolicy

        Write-Host "`n`n`t`t[!] Removed Users from policy."
    } else {
        Write-Host "`n`t`tThe group Users cannot change the system time."
    }
} else {
    Write-Host "`n`t[!] Skipping '$currentPolicy'"
}

#########################################################################################

$currentPolicy = "Event log service is running"
$checkAccessThisComputerFromTheNetwork = Prompt-Policy -policyName $currentPolicy

if ($checkAccessThisComputerFromTheNetwork -eq 0) {
    Write-Host "`n`t[!] Checking '$currentPolicy'"

    # Get service status and startup type
    $serviceStatus = (Get-Service -name "EventLog").Status
    $serviceStartupType = (Get-Service -name "EventLog").StartType

    # Do logic.
    if (($serviceStatus -eq "Running") -and ($serviceStartupType -eq "Automatic")) {
        Write-Host "`n`t`tEvent log service is running."
    } else {
        Write-Host "`n`t`tEvent log service is not running. Correcting..."

        # Fix the service
        Set-Service -Name "EventLog" -StartupType "Automatic"
        Start-Service -Name "EventLog"

        # Force update
        gpupdate /force | Out-Null
        
        Write-Host "`n`n`t`t[!] Event log service is running."
    }
} else {
    Write-Host "`n`t[!] Skipping '$currentPolicy'"
}

#########################################################################################

$currentPolicy = "Windows Defender does not exclude .exe file extensions"
$checkDefenderExeExclusion = Prompt-Policy -policyName $currentPolicy

if ($checkDefenderExeExclusion -eq 0) {
    Write-Host "`n`t[!] Checking '$currentPolicy'"

    # Registry locations behind the Group Policy "Extension Exclusions" setting
    $exclusionsPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Exclusions"
    $extensionsPolicyPath = "$exclusionsPolicyPath\Extensions"

    # Check whether the Group Policy "Extension Exclusions" setting is configured with an exe entry
    $policyHasExe = $false
    if (Test-Path $extensionsPolicyPath) {
        $policyEntries = (Get-Item -Path $extensionsPolicyPath).Property
        if (("exe" -in $policyEntries) -or (".exe" -in $policyEntries)) {
            $policyHasExe = $true
        }
    }

    # Check whether Windows Security (Defender preferences) has an exe exclusion
    $excludedExtensions = (Get-MpPreference).ExclusionExtension
    $prefsHasExe = ($null -ne $excludedExtensions) -and (("exe" -in $excludedExtensions) -or (".exe" -in $excludedExtensions))

    if ($policyHasExe -or $prefsHasExe) {
        Write-Host "`n`t`t.exe is currently excluded from Windows Defender scans. Removing..."

        # Group Policy Editor steps: set Extension Exclusions to Not Configured
        if (Test-Path $extensionsPolicyPath) {
            Remove-Item -Path $extensionsPolicyPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path $exclusionsPolicyPath) {
            Remove-ItemProperty -Path $exclusionsPolicyPath -Name "Exclusions_Extensions" -ErrorAction SilentlyContinue
        }

        # Force systemwide updates so the policy change takes effect
        gpupdate /force | Out-Null

        # Windows Security steps: remove both ".exe" and "exe" from the exclusions list
        Remove-MpPreference -ExclusionExtension ".exe" -ErrorAction SilentlyContinue
        Remove-MpPreference -ExclusionExtension "exe" -ErrorAction SilentlyContinue

        # Verify the exclusions are really gone
        $remaining = (Get-MpPreference).ExclusionExtension
        if (($null -ne $remaining) -and (("exe" -in $remaining) -or (".exe" -in $remaining))) {
            Write-Host "`n`n`t`t[!] Could not remove .exe from the exclusions. Check Windows Security manually."
        } else {
            Write-Host "`n`n`t`t[!] Removed .exe from Windows Defender extension exclusions."
        }
    } else {
        Write-Host "`n`t`tWindows Defender is not excluding .exe files."
    }
} else {
    Write-Host "`n`t[!] Skipping '$currentPolicy'"
}

#########################################################################################

$currentPolicy = "Audit Credential Validation [Success]"
$checkAuditCredentialValidation = Prompt-Policy -policyName $currentPolicy

if ($checkAuditCredentialValidation -eq 0) {
    Write-Host "`n`t[!] Checking '$currentPolicy'"

    # GUID for the Credential Validation subcategory (works on any system language)
    $subcategoryGuid = "{0CCE923F-69AE-11D9-BED3-505054503030}"

    # The Local Security Policy window shows the policy stored in the local GPO's audit.csv,
    # not the live auditpol setting, so both have to be checked and set.
    $auditCsvFolder = "$env:windir\System32\GroupPolicy\Machine\Microsoft\Windows NT\Audit"
    $auditCsvPath = "$auditCsvFolder\audit.csv"
    $gptIniPath = "$env:windir\System32\GroupPolicy\gpt.ini"
    $auditCsvHeader = "Machine Name,Policy Target,Subcategory,Subcategory GUID,Inclusion Setting,Exclusion Setting,Setting Value"

    # Get the live audit setting (CSV output, last column is the Inclusion Setting)
    $liveSetting = (auditpol /get /subcategory:$subcategoryGuid /r | ConvertFrom-Csv)."Inclusion Setting"
    $liveHasSuccess = $liveSetting -like "*Success*"

    # Get the policy (audit.csv) setting. Setting Value: 1 = Success, 2 = Failure, 3 = both.
    $policyValue = 0
    $policyHasSuccess = $false
    if (Test-Path $auditCsvPath) {
        $policyRow = Import-Csv $auditCsvPath | Where-Object { $_."Subcategory GUID" -eq $subcategoryGuid }
        if ($policyRow) {
            $policyValue = [int]$policyRow."Setting Value"
            $policyHasSuccess = (($policyValue -band 1) -eq 1)
        }
    }

    # If both are set, tell the user. Otherwise set both, keeping the Failure setting as is.
    if ($liveHasSuccess -and $policyHasSuccess) {
        Write-Host "`n`t`tCredential Validation audits Success."
    } else {
        Write-Host "`n`t`tCredential Validation does not audit Success in the policy. Enabling..."

        # Keep Failure auditing if it was already on
        $failureBit = $policyValue -band 2
        if ($liveSetting -like "*Failure*") { $failureBit = 2 }
        $newValue = 1 -bor $failureBit
        if ($newValue -eq 3) { $inclusion = "Success and Failure" } else { $inclusion = "Success" }

        # Write the policy into audit.csv, keeping any other subcategories already in it
        if (-not (Test-Path $auditCsvFolder)) {
            New-Item -Path $auditCsvFolder -ItemType Directory -Force | Out-Null
        }
        $csvLines = @()
        if (Test-Path $auditCsvPath) {
            $csvLines = @(Get-Content $auditCsvPath | Where-Object { $_ -and ($_ -notlike "Machine Name*") -and ($_ -notlike "*$subcategoryGuid*") })
        }
        $csvLines += ",System,Audit Credential Validation,$subcategoryGuid,$inclusion,,$newValue"
        Set-Content -Path $auditCsvPath -Value (@($auditCsvHeader) + $csvLines) -Encoding ASCII

        # Register the audit extension in gpt.ini so Group Policy applies audit.csv, and bump the version
        $auditExtension = "[{F3CCC681-B74C-4060-9F26-CD84525DCA2A}{0F3F3735-573D-9804-99E4-AB2A69BA5FD4}]"
        if (Test-Path $gptIniPath) {
            $gptLines = @(Get-Content $gptIniPath)
        } else {
            $gptLines = @("[General]")
        }
        $extFound = $false
        $versionFound = $false
        for ($i = 0; $i -lt $gptLines.Count; $i++) {
            if ($gptLines[$i] -like "gPCMachineExtensionNames=*") {
                $extFound = $true
                if ($gptLines[$i] -notlike "*F3CCC681-B74C-4060-9F26-CD84525DCA2A*") {
                    $gptLines[$i] = $gptLines[$i] + $auditExtension
                }
            }
            if ($gptLines[$i] -like "Version=*") {
                $versionFound = $true
                $gptLines[$i] = "Version=" + ([int]($gptLines[$i] -split "=")[1] + 1)
            }
        }
        if (-not $extFound) { $gptLines += "gPCMachineExtensionNames=$auditExtension" }
        if (-not $versionFound) { $gptLines += "Version=1" }
        Set-Content -Path $gptIniPath -Value $gptLines -Encoding ASCII

        # Apply the live setting now
        auditpol /set /subcategory:$subcategoryGuid /success:enable | Out-Null

        # Force systemwide updates
        gpupdate /force | Out-Null

        # Verify both the live setting and the policy file
        $newLive = (auditpol /get /subcategory:$subcategoryGuid /r | ConvertFrom-Csv)."Inclusion Setting"
        $newPolicyRow = Import-Csv $auditCsvPath | Where-Object { $_."Subcategory GUID" -eq $subcategoryGuid }
        if (($newLive -like "*Success*") -and $newPolicyRow -and (([int]$newPolicyRow."Setting Value" -band 1) -eq 1)) {
            Write-Host "`n`n`t`t[!] Credential Validation now audits Success. Reopen Local Security Policy to see it."
        } else {
            Write-Host "`n`n`t`t[!] Could not enable Success auditing. Check Local Security Policy manually."
        }
    }
} else {
    Write-Host "`n`t[!] Skipping '$currentPolicy'"
}