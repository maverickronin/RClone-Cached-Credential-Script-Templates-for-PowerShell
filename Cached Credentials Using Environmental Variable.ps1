####################################################################################################
#User Config
####################################################################################################
$RCloneCommands = @(
@'
copy "C:\Source" remote1:/dest1 -P
'@
@'
copy "C:\Source" remote2:/dest2 -P
'@
@'
copy "C:\Source" remote3:/dest3 -P
'@
)
$RClonePath = "C:\RClone\rclone.exe"
####################################################################################################

#Other constants
$RCloneConfigFile = "$PWD\rclone.conf"
$ENV:RCLONE_CONFIG_PASS = $null
$ENV:RCLONE_PASSWORD_COMMAND = $null
$CredentialPath = ($ENV:COMPUTERNAME + "-credential.xml")
$CredentialGood = $false
$Script:Credential = $null

function Check-CredentialPath {
    #Checks for presence of the xml file with encrypted credentials, returns true or false
    if (Test-Path $Script:CredentialPath) {
        $true
        return
    } else {
        $false
        return
    }
}

function Import-Credential {
    #Imports XML file with encrypted credentials, returns success status as true or false
    $Script:Credential = $null
    try {
        $Script:Credential = Import-Clixml -Path $Script:CredentialPath -ErrorAction Stop
        $true
        return
    } catch {
        $false
        return
    }
}

function Decrypt-Credential {
    #Decrypts credentials saved to XML file, returns success status as true or false
    try {
        $ENV:RCLONE_CONFIG_PASS = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR(($Script:Credential).Password))
        $true
        return
    } catch {
        $false
        return
    }
}

function Save-Credential {
    #Reads password and saves it to encrypted XML file
    Write-Host ""
    Write-Host "Enter Password for RClone Configuration File:"
    $Password = read-host -AsSecureString
    $Credential = New-Object -TypeName PSCredential -ArgumentList $ENV:COMPUTERNAME, $Password
    $Credential | Export-Clixml -Path ($ENV:COMPUTERNAME + "-credential.xml")
}

function Test-Credential {
    #Tests if the the encrypted credentials can decrypt the RClone configuration file
    #Returns success status as true or false
    & "$RClonePath" config encryption check --ask-password=false --config="$RcloneConfigFile" *>&1| Out-Null
    if ($LASTEXITCODE -eq 0) {
        $true
        return
    } else {
        $ENV:RCLONE_CONFIG_PASS = $null
        $false
        return
    }
}

function Cleanup {
    #Clears password from environmental variable for security
    $ENV:RCLONE_CONFIG_PASS = $null
}

#Main logic
while ($CredentialGood -eq $false) {

    #Check for existing saved credentials, prompt for new credentials
    if (-not(Check-CredentialPath)) {
        Write-Host "Cached credentials are missing."
        Save-Credential
        continue
    } else {
        Write-Host "Cached credential file exists."
    }

    #Attempt to import saved credentials, prompt for new credentials if missing
    if (-not(Import-Credential)) {
        Write-Host "Cached credentials could not be imported."
        Save-Credential
        continue
    } else {
        Write-Host "Cached credential file was imported."
    }

    #Attempt to decrypt saved credentials, prompt for new credentials if missing
    if (-not(Decrypt-Credential)) {
        Write-Host "Cached credentials could not be decrypted."
        Save-Credential
        continue
    } else {
        Write-Host "Cached credentials were decrypted."
    }

    #Test if credentials can decrypt the RClone configuration file, prompt for new credentials if
    #missing
    if (-not(Test-Credential)) {
        Write-Host "Configuration file could not be decrypted."
        Save-Credential
        continue
    } else {
        Write-Host "Configuration File Successfully decrypted."
        $CredentialGood = $true
    }
}

#Run RClone Commands

Write-Host ""
Write-Host ""
$i = 1
foreach ($RCloneCommand in $RCloneCommands) {
    Write-Host "Command $i"
    Write-Host ""
    $cmd = "`"$RClonePath`" $RCloneCommand --config=`"$RcloneConfigFile`""
    cmd /c $cmd
    Write-Host ""
    Write-Host ""
    $i++
}

#Clear password from environmental variable for security
Cleanup

#Pause at end
Write-Host ""
Write-Host "Press Enter to exit"
Read-Host