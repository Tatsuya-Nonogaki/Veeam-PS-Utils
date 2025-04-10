@ECHO OFF
SET CWD=%~dp0

if "x%~1" == "x" (
  ECHO Usage: %~nx0 VBR_JOB_NAME [OPTIONS]
  EXIT 254
)

powershell.exe "%CWD%JobStatus.ps1 %*; Exit $LastExitCode"

