### WEC-LogStash-Install
### https://www.elastic.co/downloads/
### https://www.oracle.com/java/technologies/javase-jre8-downloads.html
### https://www.codetwo.com/kb/how-to-extend-the-timeout-for-services-if-they-do-fail-to-start/#increase-starting-timeout

$ElasticDir = "C:\Elastic"
$LogStashDir = "C:\Elastic\logstash"
$Environment = 'HKLM:\System\CurrentControlSet\Control\Session Manager\Environment'


### Install Java
Start-Process -FilePath "C:\Users\administrator.hq\Downloads\jdk-11.0.7_windows-x64_bin.exe" -ArgumentList "/s" -Wait


### Set JAVA_HOME Var
$NewJAVA_HOME = "C:\Program Files\Java\jdk-11.0.7"
$CurrentJAVA_HOME = (Get-ItemProperty -Path $Environment -Name 'JAVA_HOME' -ErrorAction SilentlyContinue).JAVA_HOME

If ($CurrentJAVA_HOME -ne $NewJAVA_HOME)
{
    Remove-ItemProperty -Path $Environment -Name 'JAVA_HOME' -Force -Verbose -ErrorAction SilentlyContinue
    New-ItemProperty -Path $Environment -Name 'JAVA_HOME' -PropertyType 'String' -Value $NewJAVA_HOME -Force -Verbose   
}


### Add Java to Environment Var PATH
# $NoJavaPath = ($CurrentPath -split ';' | Where-Object -FilterScript {$_ -notlike '*Java*'}) -join ';'
$JavaPath = 'C:\Program Files\Java\jdk-11.0.7\bin'
$CurrentPath = (Get-ItemProperty -Path $Environment -Name 'PATH').Path

If ($CurrentPath -notlike "*C:\Program Files\Java\jdk-11.0.7\bin*")
{
    $NewPath = $JavaPath + ";$CurrentPath"
    Set-ItemProperty -Path $Environment -Name PATH -Value $NewPath -Force -Verbose
}


### Reboot the computer
# Restart-Computer -Force


### Set Elastic Path
If ((Test-Path $ElasticDir) -eq $False)
{
    New-Item -ItemType 'Directory' -Path 'C:\' -Name 'Elastic' -Force -Verbose
}


### Clear Logstash Path
If ((Test-Path $LogStashDir) -eq $True)
{
    Write-Host "Removing $LogStashDir" -ForegroundColor Cyan
    Remove-Item -Path $LogStashDir -Recurse -Force
}


### Expand LogStash Zip file
Expand-Archive -Path C:\Users\administrator.hq\Downloads\logstash-7.*.zip -DestinationPath $ElasticDir -Force
Rename-Item -Path 'C:\Elastic\logstash-7.7.0' -NewName $LogStashDir -Force -Verbose


### Copy client.truststore.jks to $LogStashDir\lib
### See Kafka Repo to get a client.truststore.jk
Copy-Item -Path C:\Users\administrator.hq\Downloads\client.truststore.jks -Destination "$LogStashDir\lib" -Force -Verbose


### Setup Logstash Conf
##########################
$Conf = '
### LogStash-WinLogBeat-Kafka

input
{
    beats
    {
        id => "WEF_WINWEC1"
        type => "Windows"
        port => "5044"
    }
}

output
{
    kafka
    {
        acks => "0"
        bootstrap_servers => "KAFKA0001.hq.corp:9093,KAFKA0002.hq.corp:9093,KAFKA0003.hq.corp:9093"
        client_id => "WINWEC1"
        compression_type => "gzip"
        codec => "json"
        security_protocol => "SSL"
        ssl_truststore_location => "C:\Elastic\logStash\lib\client.truststore.jks"
        ssl_truststore_password => "kafka123"
        topic_id => "Windows"
    }
}
'
##########################

$LogStashConf = 'LogStash-WinLogBeat-Kafka.conf'

New-Item -ItemType File -Path "$LogStashDir\config" -Name $LogStashConf -Force -Verbose
Set-Content -Path "$LogStashDir\config\$LogStashConf" -Value $Conf -Force -Verbose


### Set up Service
$ServiceName = "LogStash-WinBeat-Kafka"


### Delete and stop the service if it already exists.
if (Get-Service $ServiceName -ErrorAction SilentlyContinue)
{
    Write-Host "Removing $ServiceName Service" -ForegroundColor Cyan
    $service = Get-WmiObject -Class Win32_Service | Where-Object -Property name -EQ -Value $ServiceName
    $service.StopService()
    Start-Sleep -s 3
    $service.delete()
    Start-Process -FilePath C:\Windows\System32\sc.exe -ArgumentList "delete $ServiceName"

    ### Might need to restart for this to take effect
    # Restart-Computer
}


# Start-Process -FilePath "C:\Program Files\Elactic\logStash\bin\logstash.bat" -ArgumentList "-f C:\Program Files\Elactic\logStash\config\LogStash-WinLogBeat-Kafka.conf"
# Start-Process -FilePath 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -ArgumentList 'C:\Elastic\logStash\bin\logstash.bat" -f "C:\Elastic\logStash\config\LogStash-WinLogBeat-Kafka.conf'
# & "C:\Elastic\logStash\bin\logstash.bat" -f "C:\Elastic\logStash\config\LogStash-WinLogBeat-Kafka.conf"

### Create the new service.
Start-Process -FilePath C:\Elastic\logStash\lib\nssm.exe -ArgumentList "install $ServiceName $LogStashDir\bin\logstash.bat -f $LogStashDir\config\$LogStashConf"


### Set Service Time (Only in LAB)
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control' -Name 'ServicesPipeTimeout' -Value '600000' -PropertyType 'DWORD' -Force -Verbose

# Restart-Computer

### Start Service
# Get-Service -Name $ServiceName | Select-Object -Property *
Start-Service -Name $ServiceName
