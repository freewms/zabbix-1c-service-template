Param (
[string]$rac,
[string]$ras_port,
[string]$rac_usr,
[string]$rac_pwd
)

# Function is to bring to the format understands zabbix
function convertto-encoding ([string]$from, [string]$to){
    begin{
        $encfrom = [system.text.encoding]::getencoding($from)
        $encto = [system.text.encoding]::getencoding($to)
    }
    process{
        $bytes = $encto.getbytes($_)
        $bytes = [system.text.encoding]::convert($encfrom, $encto, $bytes)
        $encto.getstring($bytes)
    }
}

# Extract value from text line specified to RAC stdout
function get_value_from_text_line([string]$key_and_value) {
	
	$value = ""
	
	$pos = $key_and_value.IndexOf(":")
	if ($pos -gt 0) {
		$value = $key_and_value.Substring($pos+2, $key_and_value.Length-$pos-2)
		$value = $value.Trim(" ")
		$value = $value.Trim("`"")
	} 
	return $value

}

# Extract key from text line specified to RAC stdout
function get_key_from_text_line([string]$key_and_value) {
	
	$key = ""
	
	$pos = $key_and_value.IndexOf(":")
	if ($pos -gt 0) {
		$key = $key_and_value.Substring(0, $pos)
		$key = $key.Trim("`"")
	} 
	return $key

}

function get_clusters_info()
{
	
	$data_array = @()
	
	try 
	{
		$stdout_heap = & $rac localhost:$ras_port cluster list 2>&1
		
		if (!$?)
		{	
			write-host $($stdout_heap | convertto-encoding "cp866" "utf-8")
			exit;
		}
		
	} 
	catch 
	{
		write-host $($_.Exception.Message | convertto-encoding "cp866" "utf-8")
		exit;
	}
	
	$cluster_id_heap =  $stdout_heap | Select-String -Pattern "cluster:*"
	$cluster_name_heap =  $stdout_heap | Select-String -Pattern "name:*"
	
	if ($cluster_id_heap.GetType().fullname -eq "Microsoft.PowerShell.Commands.MatchInfo")
	{	
		$cluster_id_heap = [array]$cluster_id_heap
		$cluster_name_heap = [array]$cluster_name_heap
	}
		
	if ($cluster_name_heap.Count -eq $cluster_name_heap.Count) {
		$array_count = $cluster_name_heap.Count
	} else {
		write-host "Error parsing infobase list"
		write-host $($_.Exception)
		exit
	}

	if ($array_count -eq 0)
	{
		write-host "No clusters"
		exit
	}		
	
	for ($i = 0; $i -lt $array_count; $i++) 
	{
		$description = $(get_value_from_text_line $cluster_id_heap[$i]) + " : " + $(get_value_from_text_line $cluster_name_heap[$i])
		$data_array += $description
	}	

	return $data_array

}

function get_infobases_info([string]$cluster_id){

	$data_array	 = @()
		
	try {
		if ($rac_usr -eq "") {
			$stdout_heap = & $rac localhost:$ras_port infobase summary list --cluster=$cluster_id 2>&1
		} else {
			$stdout_heap = & $rac localhost:$ras_port infobase summary list --cluster=$cluster_id --cluster-user=$rac_usr --cluster-pwd=$rac_pwd 2>&1
		}
		
		if (!$?)
		{	
			write-host $($stdout_heap | convertto-encoding "cp866" "utf-8")
			exit;
		}
		
	} 
	catch
	{
		write-host $($_.Exception.Message | convertto-encoding "cp866" "utf-8")
		exit
	}
	
	$infobase_id_heap =  $stdout_heap | Select-String -Pattern "infobase:*"
	$infobase_name_heap =  $stdout_heap | Select-String -Pattern "name:*"
	
	if ($infobase_id_heap -eq $null) {
		return ""
	}
		
	if ($infobase_id_heap.GetType().fullname -eq "Microsoft.PowerShell.Commands.MatchInfo")
	{	
		$infobase_id_heap = [array]$infobase_id_heap
		$infobase_name_heap = [array]$infobase_name_heap
	}

	if ($infobase_id_heap.Count -eq $infobase_name_heap.Count) {
		$array_count = $infobase_id_heap.Count
	} else {
		write-host "Error parsing infobase list"
		exit
	} 
		
	for ($i = 0; $i -lt $array_count; $i++) {		
		$description = $(get_value_from_text_line $infobase_id_heap[$i]) + " : " + $(get_value_from_text_line $infobase_name_heap[$i])
		$data_array += $description
	}
	
	return $data_array

}

$data_array = get_clusters_info

$line = ""
$line = $line + "{`n"
$line = $line + " `"data`":[`n"
$line = $line + "`n"

$infobase_count = 0

foreach ($cluster_description in $data_array){
	
	$cluster_id = get_key_from_text_line $cluster_description
	$cluster_name = get_value_from_text_line $cluster_description
		
	$infobase_array = get_infobases_info $cluster_id

	foreach($infobase_description in $infobase_array)
	{
		$infobase_count = 1
		$line = $line + "  { `"{#CLUSTERNAME}`" : `"" + $cluster_name + "`", `"{#CLUSTERID}`" : `"" + $cluster_id + "`", `"{#INFOBASENAME}`" : `"" + $(get_value_from_text_line $infobase_description) + "`", `"{#INFOBASEID}`" : `"" + $(get_key_from_text_line $infobase_description) + "`" },`n"
	}

}

if ($infobase_count -lt 1){
		write-host "No infobases"
		exit
}

$line = $line.TrimEnd(",`n")
$line = $line + "`n"
$line = $line + "`n ]"
$line = $line + "`n}"
$line = $line | convertto-encoding "cp866" "utf-8"

write-host $line
