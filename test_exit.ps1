$proc = Start-Process cmd.exe -ArgumentList '/c', '"exit 42"' -PassThru -Wait
exit $proc.ExitCode
