# RClone Cached Credential Script Templates for PowerShell

These are PowerShell script templates for programmatically running RClone commands on Windows while keeping the RClone configuration file encrypted.

This readme is a bit abbreviated as this is just meant a starting point for others to customize.

## Credential Encryption Process

This script uses Windows' built in account level credential encryption.

Of important note is that the encryption key is tied to both the specific computer and user account they are created under.  The cached credentials can only be decrypted by processes running under the same account that originally encrypted it.  It is also tied to the account's password.  A local computer account will loose the ability to decrypt previously encrypted credentials if the account's password is changed by means other than through the GUI via Ctrl+Alt+Delete or password expiration upon login.  Because of this it is recommend to also keep the RClone configuration file in your password manager so you can edit it without starting over from scratch.

This IS NOT as secure as a proper password manager as it can easily be programmatically extracted by processes running as the user but it does keep it out of plaintext at rest.

## Password Passing Methods

There are two different PowerShell scripts which give the plaintext of password to RClone in different ways after it is decrypted.  One uses the plaintext of the password in the RCLONE_CONFIG_PASS environmental variable while the other uses the RCLONE_PASSWORD_COMMAND to run a script with passes the plaintext password via StdOut.  Both have their advantages and disadvantages.

The downside of RCLONE_CONFIG_PASS is that the plaintext of password will hang around in memory until all the RCLone commands are finished where it is easily ready by other processes.  The downside of RCLONE_PASSWORD_COMMAND is that PowerShell's StdOut is easily logged, including an OS level Group Policy.  The RCLONE_PASSWORD_COMMAND will attempt to check for this policy and stop without decrypting the password if it detects the policy is active.

To keep from needing an extra file, the RCLONE_PASSWORD_COMMAND version calls itself with an argument which causes it to just return the decrypted password in StdOut.

## Notes

I built this to match my preferred organization, keeping separate folders with their own scripts, config files, separate encryption passwords, and syncing that folder to different computers where the same script and config file will be used.

## Usage

* Copy one of the PowerShell scripts and the .bat file into a folder with an rclone.conf file
* Rename them if desired
* In the PowerShell script, edit $RClonePath to point to your RClone executable
* In the PowerShell script edit $RCloneCommands with the commands to run
* In the .bat file, edit the directories to point to the new folder and/or file name
* Every time the script is run it will check for a \<HOSTNAME>-credential.xml file and prompt you to save a new password to it the file is missing or it doesn't work.
  * If the credentials do work, the script will proceed without user interaction
* If you want, remove the Read-Host from the end of the PowerShell script if you don't need it to pause at the end to display the status.