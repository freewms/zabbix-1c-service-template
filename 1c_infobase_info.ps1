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

function get_max_value($object)
{
	$max_value = 0;
	foreach($pos in $object)
	{
		$str = $pos.Matches[0]
		$str = $str.ToString()
		$str_int = [int]$str.Split(":")[1]
		if ($max_value -lt $str_int) {$max_value = $str_int}
	}
	
	return $max_value
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
		$stdout_heap = & $rac localhost:$ras_port session list --cluster=$cluster_id --infobase=$infobase_id --cluster-user=$rac_usr --cluster-pwd=$rac_pwd 2>&1
		
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
		
	$sessions_app_id_heap =  $stdout_heap | Select-String -Pattern "app-id*"	
	$sessions_blocked_by_ls =  $stdout_heap | Select-String "blocked-by-ls[ ]*:[ ]*[1-9][0-9]*"
	$sessions_blocked_by_dbms =  $stdout_heap | Select-String "blocked-by-dbms[ ]*:[ ]*[1-9][0-9]*" 
		
	$sessions_type_designer = $sessions_app_id_heap | Select-String -Pattern ": Designer"
	$sessions_type_background_job = $sessions_app_id_heap | Select-String -Pattern ": BackgroundJob"
	$sessions_type_thin_client = $sessions_app_id_heap | Select-String -Pattern ": 1CV8C"
	$sessions_type_thick_client = $sessions_app_id_heap | Select-String -Pattern ": 1CV8" | Select-String -Pattern "1CV8C" -NotMatch
	$sessions_type_com_connection = $sessions_app_id_heap | Select-String -Pattern ": COMConnection"
	$sessions_type_web_service = $sessions_app_id_heap | Select-String -Pattern ": WSConnection"
	$sessions_type_com_console = $sessions_app_id_heap | Select-String -Pattern ": COMConsole"
	$sessions_type_unknown = $sessions_app_id_heap | Select-String -Pattern "1CV8*", ": BackgroundJob", ": Designer", ": WSConnection",": COMConnection",": COMConsole" -notMatch
	$sessions_duration = $stdout_heap | Select-String "duration-current[ ]*:[ ]*[1-9][0-9]*"
	$sessions_duration_dbms = $stdout_heap | Select-String "duration-current-dbms[ ]*:[ ]*[1-9][0-9]*"
	
	$max_duration = get_max_value $sessions_duration
	$max_duration_dbms = get_max_value $sessions_duration_dbms
	$lock_by_ls_count = $sessions_blocked_by_ls.Count
	$lock_by_dbms_count = $sessions_blocked_by_dbms.Count
						
	$data_array +=  [int]$sessions_app_id_heap.Count
	$data_array +=  [int]$lock_by_dbms_count
	$data_array +=  [int]$lock_by_ls_count
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
