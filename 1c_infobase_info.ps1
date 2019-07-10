Param (
[string]$rac,
[string]$ras_port,
[string]$cluster_id,
[string]$infobase_id,
[string]$rac_usr,
[string]$rac_pwd
)

# Function is to bring to the format understands zabbix
function convertto-encoding ([string]$from, [string]$to)
{
    begin
	{
        $encfrom = [system.text.encoding]::getencoding($from)
        $encto = [system.text.encoding]::getencoding($to)
    }
    process
	{
        $bytes = $encto.getbytes($_)
        $bytes = [system.text.encoding]::convert($encfrom, $encto, $bytes)
        $encto.getstring($bytes)
    }
}

# Extract value from text line specified to RAC stdout
function get_value_from_text_line([string]$key_and_value) {
	
	$value = ""
	$pos = $key_and_value.IndexOf(":")
	
	if ($pos -gt 0) 
	{
		$value = $key_and_value.Substring($pos+2, $key_and_value.Length-$pos-2)
		$value = $value.Trim("`"")
	} 
	return $value

}

function return_json($data_array=@(), $iserror=0)
{
	$line = ""
	$line = $line + "{`n"
	
	if ($iserror -eq 1)
	{
		$line = $line + "`"ERRORMSG`" : `""+$data_array[0]+"`"`n" 
	} else {
		$line = $line + "`"SESSIONS`" : `""+$data_array[0]+"`",`n"
		$line = $line + "`"LOCK_BY_DBMS`" : `""+$data_array[1]+"`",`n"
		$line = $line + "`"LOCK_BY_LS`" : `""+$data_array[2]+"`",`n"
		$line = $line + "`"SESSIONS_DESIGNER`" : `""+$data_array[3]+"`",`n"
		$line = $line + "`"SESSIONS_BACKGROUND_JOB`" : `""+$data_array[4]+"`",`n"
		$line = $line + "`"SESSIONS_THIN_CLIENT`" : `""+$data_array[5]+"`",`n"
		$line = $line + "`"SESSIONS_THICK_CLIENT`" : `""+$data_array[6]+"`",`n"
		$line = $line + "`"SESSIONS_COM_CONNECTION`" : `""+$data_array[7]+"`",`n"
		$line = $line + "`"SESSIONS_WEB_SERVICE`" : `""+$data_array[8]+"`",`n"
		$line = $line + "`"SESSIONS_COM_CONSOLE`" : `""+$data_array[9]+"`",`n"
		$line = $line + "`"SESSIONS_UNKNOWN`" : `""+$data_array[10]+"`",`n"
		$line = $line + "`"MAX_DURATION`" : `""+$data_array[11]+"`",`n"
		$line = $line + "`"MAX_DURATION_DBMS`" : `""+$data_array[12]+"`",`n"
		$line = $line + "`"ERRORMSG`" : `"`"`n" 
	}
	
	$line = $line + "}"
	$line = $line | convertto-encoding "cp866" "utf-8"
	write-host $line
	exit
}

function get_sessions_info()
{

	$data_array = @()
			
	try
	{
		$stdout_heap = & $rac localhost:$ras_port session list --cluster=$cluster_id --infobase=$infobase_id 2>&1
		
		if (!$?)
		{	
			$data_array += $stdout_heap
			return_json $data_array 1
		}
	} 
	catch 
	{
		$data_array += $($_.Exception.Message)
		return_json $data_array 1
	}
		
	$sessions_app_id_heap =  $stdout_heap | Select-String -Pattern "app-id:*"	
	$sessions_blocked_by_dbms =  $stdout_heap | Select-String -Pattern "blocked_by_dbms:*"
	$sessions_blocked_by_ls =  $stdout_heap | Select-String -Pattern "blocked_by_ls:*"
		
	$sessions_type_designer = $sessions_app_id_heap | Select-String -Pattern ": Designer"
	$sessions_type_background_job = $sessions_app_id_heap | Select-String -Pattern ": BackgroundJob"
	$sessions_type_thin_client = $sessions_app_id_heap | Select-String -Pattern ": 1CV8C"
	$sessions_type_thick_client = $sessions_app_id_heap | Select-String -Pattern ": 1CV8" | Select-String -Pattern "1CV8C" -NotMatch
	$sessions_type_com_connection = $sessions_app_id_heap | Select-String -Pattern ": COMConnection"
	$sessions_type_web_service = $sessions_app_id_heap | Select-String -Pattern ": WSConnection"
	$sessions_type_com_console = $sessions_app_id_heap | Select-String -Pattern ": COMConsole"
	$sessions_type_unknown = $sessions_app_id_heap | Select-String -Pattern "1CV8*", ": BackgroundJob", ": Designer", ": WSConnection",": COMConnection",": COMConsole" -notMatch
	$sessions_duration = $stdout_heap | Select-String -Pattern "duration-current:*"
	$sessions_duration_dbms = $stdout_heap | Select-String -Pattern "duration-current-dbms:*"
	
	$max_duration = 0;
	foreach($duration in $sessions_duration)
	{
		[int]$current_duration = get_value_from_text_line $duration
		if ($max_duration -lt $current_duration) {$max_duration = $current_duration}
	}
	
	$max_duration_dbms = 0;
	foreach($duration_dbms in $sessions_duration)
	{	
		[int]$current_duration_dbms = get_value_from_text_line $duration_dbms
		if ($max_duration_dbms -lt $current_duration_dbms) {$duration_dbms = $current_duration_dbms}
	}
						
	$data_array +=  [int]$sessions_app_id_heap.Count
	$data_array +=  [int]$sessions_blocked_by_dbms.Count
	$data_array +=  [int]$sessions_blocked_by_ls.Count
	$data_array +=  [int]$sessions_type_designer.Count
	$data_array +=  [int]$sessions_type_background_job.Count
	$data_array +=  [int]$sessions_type_thin_client.Count
	$data_array +=  [int]$sessions_type_thick_client.Count
	$data_array +=  [int]$sessions_type_com_connection.Count
	$data_array +=  [int]$sessions_type_web_service.Count
	$data_array +=  [int]$sessions_type_com_console.Count
	$data_array +=  [int]$sessions_type_unknown.Count
	$data_array +=  [int]$($max_duration/1000)
	$data_array +=  [int]$($max_duration_dbms/1000)

	return $data_array
}

$data_array = get_sessions_info
return_json $data_array







