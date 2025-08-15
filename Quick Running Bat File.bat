rem Move to directory RClone DIrectory
PushD "C:\RClone Scripts"

rem Launch main script in new window
PowerShell -NoProfile -command "&{start-process powershell -ArgumentList '-NoProfile -ExecutionPolicy bypass -file ""C:\RClone Scripts\RClone Script.ps1""'}"