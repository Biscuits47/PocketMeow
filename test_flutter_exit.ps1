$proc = Start-Process cmd.exe -ArgumentList '/c', '""C:\Users\krilra\flutter\bin\flutter.bat"" build apk --release' -PassThru -Wait
echo $proc.ExitCode
