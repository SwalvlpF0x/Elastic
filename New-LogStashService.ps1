# Delete and stop the service if it already exists.
if (Get-Service Logstash -ErrorAction SilentlyContinue) {
  $service = Get-WmiObject -Class Win32_Service -Filter "name='Logstash'"
  $service.StopService()
  Start-Sleep -s 1
  $service.delete()
}

$workdir = Split-Path $MyInvocation.MyCommand.Path

# Create the new service.
New-Service -name Logstash `
  -displayName Logstash `
  -binaryPathName "C:\Logstash\logstash-7.6.0\bin\logstash.bat -f C:\Logstash\logstash-7.6.0\\config\logstash-infile-outstdout.conf"

# Attempt to set the service to delayed start using sc config.
Try {
  Start-Process -FilePath sc.exe -ArgumentList 'config Logstash start= delayed-auto'
}
Catch { Write-Host -f red "An error occured setting the service to delayed start." }
