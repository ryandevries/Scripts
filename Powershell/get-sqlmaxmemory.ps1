FUNCTION Get-SqlMaxMemory {
<#
.SYNOPSIS 
    Generates a value to be used for max memory
.DESCRIPTION
	Generates a value to be used for max memory (in MB) based on the total available RAM for the system.  Reserves 1 GB of RAM for the OS, 1 GB for each 4 GB of RAM installed from 4–16 GB, and then 1 GB for every 8 GB RAM installed above 16 GB RAM
.PARAMETER  RAM
	Requires the amount of RAM currently in the system, uses bytes if no unit is specified
.EXAMPLE
    PS C:\> Get-SqlMaxMemory -RAM 16GB
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/06/01
    Version     : 1
.LINK
    https://www.sqlskills.com/blogs/jonathan/how-much-memory-does-my-sql-server-actually-need/
.INPUTS
    [long]
.OUTPUTS
    [long]
#>
    [CmdletBinding()]
    Param(
	    [Parameter(Position=0,Mandatory,HelpMessage="Amount of RAM in the system, uses bytes if no unit is specified",ValueFromPipeline)]
        [ValidateNotNullorEmpty()]
	    [long]$RAM
    )

    begin {
        Write-Verbose "Starting $($MyInvocation.Mycommand)"  
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        Write-Verbose ($PSBoundParameters | out-string)
    }
 
    process {
        Write-Verbose "Starting with flat 1 GB reservation for OS"
        $os_memoryMB = 1024
        Write-Verbose "Converting $ram bytes to megabytes"  
        $total_memoryMB = $ram / 1MB
        if ($total_memoryMB -ge 4096) {
            Write-Verbose "Total RAM : $total_memoryMB`tMB -ge 4 GB"  
            $processed = 4096
            while ($processed -le $total_memoryMB){
                if ($processed -le 16384){
                    # Add 1 GB to reserve for every 4 GB installed between 4 and 16 GB
                    Write-Verbose "Processed : $processed`tMB -le 16 GB, adding 1 GB to OS reservation, adding 4 GB to processed"
                    $os_memoryMB += 1024
                    $processed   += 4096
                    if ($processed -gt $total_memoryMB){
                        # Add 1/4 GB per GB of total RAM % 4 GB
                        $overage = $processed - $total_memoryMB
                        $gap     = 4096 - $overage
                        if ($gap -gt 0){
                            $gap_os_memoryMB = $gap * (1024 / 4096)
                            $os_memoryMB    += $gap_os_memoryMB
                            Write-Verbose "Remainder : $gap`tMB, adding 1/4 GB for each 1 GB of remainder: $gap_os_memoryMB MB to OS reservation"
                        }
                    }
                } 
                else {
                    # Add 1 GB to reserve for every 8 GB installed over 16 GB
                    Write-Verbose "Processed : $processed`tMB -gt 16 GB, adding 1 GB to OS reservation, adding 8 GB to processed"
                    $os_memoryMB += 1024
                    $processed   += 8192
                    if ($processed -gt $total_memoryMB){
                        # Add 1/8 GB per GB of total RAM % 8 GB
                        $overage = $processed - $total_memoryMB
                        $gap     = 8192 - $overage
                        if ($gap -gt 0){
                            $gap_os_memoryMB = $gap * (1024 / 8192)
                            $os_memoryMB    += $gap_os_memoryMB
                            Write-Verbose "Remainder : $gap`tMB, adding 1/8 GB for each 1 GB of remainder: $gap_os_memoryMB MB to OS reservation"
                        }
                    }
                }
            }
            $sql_memoryMB = $total_memoryMB - $os_memoryMB
            Write-Verbose "Host RAM  : $os_memoryMB`tMB"
            Write-Verbose "SQL RAM   : $sql_memoryMB`tMB"
        }
        else {
            # Set reservation to all but 1GB for systems with < 4 GB
            Write-Verbose "Total RAM : $total_memoryMB MB -lt 4 GB.  No additional reservation for OS added"  
            $sql_memoryMB = $total_memoryMB - $os_memoryMB
            if ( $sql_memoryMB -lt 0 ){ $sql_memoryMB = 0 }
        }
        $sql_memoryMB
    }

    end { 
        Write-Verbose "Ending $($MyInvocation.Mycommand)"
        Remove-Variable sql_memoryMB -ErrorAction SilentlyContinue
    }
}
