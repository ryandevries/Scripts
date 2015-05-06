<# 
.SYNOPSIS 
    Emails a list of failed production SQL jobs over the last 24 hours
.DESCRIPTION 
    Dependendencies  : SQL Server SMO, SQLFunctions Module, Ability to send mail
    SQL Permissions  : SQLAgentUserRole on each of the instances and read to ServerInventory database
.NOTES 
    Author     : Ryan DeVries
    Updated    : 2015-02-12
    Source     : Based on http://www.sqlsandwiches.com/2012/01/30/find-failed-sql-jobs-powershell/
#> 

#-----------------------------------------------#
# VARIABLES
#-----------------------------------------------#

$get_instances_query = @"
SELECT s.name + CASE WHEN si.name = 'Default Instance' THEN '' ELSE '\' + si.name END AS InstanceName
FROM [dbo].[SQLInstances] si 
JOIN [dbo].[Servers] s ON si.serverid = s.serverid 
WHERE s.environment = 'Production' AND si.code = 2 AND si.Edition not like 'Express%'
"@
                
$datefull          = Get-Date
$today             = $datefull.ToShortDateString()
$smtp_server       = "FQDN of Exchange"
$smtp_from         = "SQLJobFailures@domain.com"
$smtp_subject      = "Failed SQL Jobs for $today"
$smtp_body         = "Here is a list of failed Production SQL Jobs for $today (over the last 24 hours)"
$errormessage      = "Error messages for the failed jobs for $today (over the last 24 hours)`r`n-------------------------------------------------------"
$smtp_recipients   = get-content $PSScriptRoot\SMTPTo.txt
$smtp_attachment   = "$PSScriptRoot\ErrorMessages.txt"
$inventoryserver   = 'InventoryServer'
$inventorydatabase = 'ServerInventory'

#-----------------------------------------------#
# START
#-----------------------------------------------#

[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | out-null

# Pull all Production SQL instances from Server Inventory
$sql_instances = (invoke-sqlcmd -ServerInstance $inventoryserver -Database $inventorydatabase -Query $get_instances_query).InstanceName

# Set up email message
$msg         = new-object Net.Mail.MailMessage
$smtp        = new-object Net.Mail.SmtpClient($smtp_server)
$msg.Body    = $smtp_body
$msg.From    = $smtp_from
$msg.Subject = $smtp_subject

foreach($recipient in $smtp_recipients){$msg.To.Add($recipient)}

# Loop through each instance
foreach($instance in $sql_instances){

    # Set up SMO server object to pull data from
    $srv = New-Object "Microsoft.SqlServer.Management.Smo.Server" $instance;
            
    # Loop through each job on the instance
    foreach ($job in $srv.Jobserver.Jobs){
        # Set up job variables
        $jobName           = $job.Name;
        $jobID             = $job.JobID;
        $jobEnabled        = $job.IsEnabled;
        $jobLastRunOutcome = $job.LastRunOutcome;
        $jobLastRun        = $job.LastRunDate;
                                    
        # Filter out jobs that are disabled or have never run
        if($jobEnabled -eq "true" -and $jobLastRun){  
            # Calculate the number of days ago the job ran
            $datediff = New-TimeSpan $jobLastRun $today
                   
            # Check to see if the job failed in the last 24 hours   
            if($datediff.days -le 1 -and $jobLastRunOutcome -eq "Failed"){
                # Append failed job information to the message body
                $msg.body += "`n`nFAILED JOB INFO: `n`tSERVER`t= $instance `n`tJOB`t`t= $jobName `n`tLASTRUN`t= $jobLastRunOutcome `n`tLASTRUNDATE`t= $jobLastRun"                
                
                # Loop through each step in the job
                foreach ($step in $job.JobSteps){
                    # Set up step variablesLoo
                    $stepName           = $step.Name;
                    $stepID             = $step.ID;
                    $stepLastRunOutcome = $step.LastRunOutcome;

                    # Filter out steps that succeeded
                    if($stepLastRunOutcome -eq "Failed"){
                        # Get the latest message returned for the failed step
                        $stepMessage = (Invoke-Sqlcmd2 -ServerInstance $instance -Database msdb -Query "SELECT TOP 1 message FROM msdb.dbo.sysjobhistory WHERE job_id = '$jobID' AND step_id = '$stepID' ORDER BY instance_id DESC").message
                        
                        # Filter out steps that didn't have a chance to run (have a failed status but no message)
                        if($stepMessage.length -gt 0){
                            # Format error messages a little bit
                            $stepMessage = $stepMessage -replace 'Source:', "`r`n`r`nSource:"
                            $stepMessage = $stepMessage -replace 'Description:', "`r`nDescription:"

                            # Append failed step information to the message body
                            $errormessage += "`r`nSERVER`t`t= $instance `r`nJOB`t`t= $jobName `r`nSTEP NAME`t= $stepName `r`nMESSAGE`t`t= $stepMessage `r`n`r`n-------------------------------------------------------"
                        }
                    }
                }
            } 
        }
    }
}

# Change the message if there were no failed jobs detected
if(($msg.body | measure-object -Line).lines -eq 1){
    $msg.body = "There were no failed Production SQL Jobs for $today (over the last 24 hours)"
    # Send completed message
    $smtp.Send($msg)
}
else{
    # Appends all step error messages to attachment file
    $errormessage > $smtp_attachment
    # Create attachment object and attaches to email message
    $att = new-object Net.Mail.Attachment($smtp_attachment)
    $msg.Attachments.Add($att)
    # Send completed message
    $smtp.Send($msg)
    # Clean up attachment from memory and text file created
    $att.Dispose()
    Remove-Item -path $smtp_attachment
}
# Diagnostics
# $msg.Body > C:\TEMP\failedjobs_$($datefull.ToString("yyyyMMdd")).txt

#-----------------------------------------------#
# END
#-----------------------------------------------#
