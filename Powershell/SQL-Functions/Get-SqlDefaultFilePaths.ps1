$servers = Get-SqlInstances
$results = @()
foreach($server in $servers){

    $SMOServer = new-object ('Microsoft.SqlServer.Management.Smo.Server') $server.InstanceName 
  
    # Get the Default File Locations 
  
    $DefaultDataLocation = $SMOServer.Settings.DefaultFile 
    $DefaultLogLocation  = $SMOServer.Settings.DefaultLog 
  
    if ($DefaultDataLocation.Length -eq 0){ $DefaultDataLocation = $SMOServer.Information.MasterDBPath    }
    if ($DefaultLogLocation.Length  -eq 0){ $DefaultLogLocation  = $SMOServer.Information.MasterDBLogPath }

    $holder = New-Object -TypeName PSObject
    Add-Member -InputObject $holder -MemberType NoteProperty -Name 'InstanceName'          -Value $server.InstanceName
    Add-Member -InputObject $holder -MemberType NoteProperty -Name 'DefaultDataLocation'   -Value $DefaultDataLocation
    Add-Member -InputObject $holder -MemberType NoteProperty -Name 'DefaultLogLocation'    -Value $DefaultLogLocation
    Add-Member -InputObject $holder -MemberType NoteProperty -Name 'DefaultBackupLocation' -Value $SMOServer.BackupDirectory
    $results += $holder

}
$results | export-csv -NoTypeInformation C:\TEMP\paths.csv