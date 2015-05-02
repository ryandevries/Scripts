<#  
.SYNOPSIS  
    Breaks text-based file over specified size into files of specified length and stores them in a subdirectory 
.DESCRIPTION  
    Purges all files in $destpath, then splits file up into $numlines chunks and stores in $destpath if the file is over $maxsize 
.NOTES  
    Author     : Ryan DeVries 
    Updated    : 2015-04-30 
#>  
 
#-----------------------------------------------# 
# VARIABLES 
#-----------------------------------------------# 
 
$sourcepath = 'C:\Temp' 
$sourcefile = 'srcfilename.sql' 
$destfile   = 'dstfilename' 
$destpath   = 'C:\Temp\dst' 
$maxsize    = 5000KB 
$numlines   = 10000 
 
#-----------------------------------------------# 
# START 
#-----------------------------------------------# 
$start = get-date 
try { 
    remove-item "$destpath\*" -ErrorAction Stop 
    $file = get-item "$sourcepath\$sourcefile" -ErrorAction Stop 
    if($file.length -gt $maxsize) { 
        $count = 1 
        get-content "$sourcepath\$sourcefile" -ReadCount $numlines |  
        foreach-object {  
            $destfilename = "{0}{1}.{2}" -f ($destfile, $count, "sql") 
            [system.io.file]::WriteAllLines("$destpath\$destfilename", $_) 
            $count++ 
        } 
    } 
} 
catch [system.exception] { 
    write-error $_.Exception.Message -TargetObject $_.Exception.ItemName 
    exit 1 
} 
$end = get-date 
(New-TimeSpan -start $start -end $end).TotalSeconds 
#-----------------------------------------------#   
# END 
#-----------------------------------------------#