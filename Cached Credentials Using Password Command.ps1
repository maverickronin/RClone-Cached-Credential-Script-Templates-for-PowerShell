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
$Script:PlainTextPassword = $null
$Script:Credential = $null

function Get-ScriptName {
    #Takes the command line the script was started with and figures out it's own filename
    param([string] $FullCommand)

    $FullCommand = $FullCommand.Trim()
    $Suffix = $FullCommand
    #Iterate through string to find number of trailing characters after last instance of ".ps1",
    #case insensitive, and trim them from the end of the string
    while ($true) {
        if ($Suffix -imatch '(?<=\.ps1).*$') {
            $Suffix = $Matches[0]
        } else {
            break
        }
    }
    $Output = $FullCommand.Substring(0,($FullCommand.Length - $Suffix.Length))
    #Iterate through string, removing substrings from beginning which end with illegal Windows
    #file/folder name characters until only the file name is left
    while ($true) {
        if ($Output -imatch '^[^""\\\:\?\|\*\<\>]*(?=[""\\\:\?\|\*\<\>]).') {
            $Output = $Output.Substring($($Matches[0].Length))
        } else {
            break
        }
    }
    $Output
    return
}

function Check-PowerShellLogging {
    #Basic checks for PowerShell Group Policy logging registry keys.  Exits if  they are active.
    if (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription") {
        if ($(get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription").EnableTranscripting -eq 1) {
            Write-Host "PowerShell transcription is enabled"
            exit 1
        }
    }
    if (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging") {
        if ($(get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging").EnableModuleLogging -eq 1) {
            Write-Host "PowerShell module logging is enabled"
            exit 1
        }
    }
}

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
        $Script:Credential = Import-Clixml -Path "$Script:CredentialPath" -ErrorAction Stop
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
        $Script:PlainTextPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR(($Script:Credential).Password))
        $true
        return
    } catch {
        $Script:PlainTextPassword = $null
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
        $Script:PlainTextPassword = $null
        $false
        return
    }
}

#Main logic
Check-PowerShellLogging

#Have script figure out its own file name so it can call itself
if ($MyInvocation.line -notin "", $null) {
    $ScriptName = Get-ScriptName $MyInvocation.Line
} else {
    $ScriptName = Get-ScriptName $MyInvocation.InvocationName
}
$ENV:RCLONE_PASSWORD_COMMAND = "PowerShell -NoProfile -ExecutionPolicy bypass -file `"$ScriptName`" GetCredential"


while ($CredentialGood -eq $false) {

    #Check for existing saved credentials, prompt for new credentials if missing or exit with error
    #if GetCredential parameter is specified
    if (-not(Check-CredentialPath)) {
        Write-Host "Cached credentials are missing."
        if ($args[0] -eq "GetCredential") {exit 1}
        Save-Credential
        continue
    } else {
        if ($args[0] -ne "GetCredential") { Write-Host "Cached credential file exists." }
    }

    #Attempt to import saved credentials, prompt for new credentials if missing or exit with error
    #if GetCredential parameter is specified
    if (-not(Import-Credential)) {
        Write-Host "Cached credentials could not be imported."
        if ($args[0] -eq "GetCredential") {exit 1}
        Save-Credential
        continue
    } else {
        if ($args[0] -ne "GetCredential") { Write-Host "Cached credential file was imported." }
    }

    #Attempt to decrypt saved credentials, prompt for new credentials if missing or exit with error
    #if GetCredential parameter is specified
    if (-not(Decrypt-Credential)) {
        Write-Host "Cached credentials could not be decrypted."
        if ($args[0] -eq "GetCredential") {exit 1}
        Save-Credential
        continue
    } else {
        if ($args[0] -ne "GetCredential") { Write-Host "Cached credentials were decrypted." }
    }

    #Test if credentials can decrypt the RClone configuration file, prompt for new credentials if
    #missing
    if ($args[0] -ne "GetCredential") {
        if (-not(Test-Credential)) {
            Write-Host "Configuration file could not be decrypted."
            Save-Credential
            continue
        } else {
            Write-Host "Configuration File Successfully decrypted."
            $CredentialGood = $true
        }
    #Return plaintext password if GetCredential parameter is specified
    } else {
        Write-Host $Script:PlainTextPassword
        exit 0
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

#Pause at end
Write-Host ""
Write-Host "Press Enter to exit"
Read-Host