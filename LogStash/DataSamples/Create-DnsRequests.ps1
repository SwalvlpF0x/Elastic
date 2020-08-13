while (0 -ne 1)
{
  Resolve-DnsName  -Server 127.0.0.1 -Name "$count.com"
  $Count += 1
}
