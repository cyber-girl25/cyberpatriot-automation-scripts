# cyberpatriot-automation-scripts
A bunch of scripts to automate routine tasks like policy checks/changes for (mainly) CyberPatriot and similar competitions

## Currently automated tasks
### Policies
 - A sufficient password history is being kept
 - Everyone may not access this computer from the network
 - Let Everyone permissions apply to anonymous users [disabled]
 - A secure minimum password length is required
 - A secure maximum password age exists
 - A secure lockout threshold exists
 - Passwords must meet complexity requirements
 - Behavior of the elevation prompt for administrators in Admin Approval Mode configured to prompt

## Things I have skipped and need to come back
If you're a member of this project, feel free to work on this!
### Policies
 - Windows Defender does not exclude .exe file extensions
    - Why I skipped this: I figured out how to get rid of these file extensions locally, but turns out gpedit changes are different from local changes. I want to learn registry keys properly before I write the code for changing them. Also, the Windows Defender part of this policy change seems a bit tacky to automate, and I'm going to research this soon to see if it can even be automated at all (I'm sure it can)
 - Credential Validation [Success]
    - Same issue as above
 - Unauthorized users may not create global objects
    - I'll come back to this, I don't want to deal with those account and group IDs and stuff right now