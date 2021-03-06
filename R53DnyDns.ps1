####Change these to your values####
$DynamicSubzone = "yourhost.domain.com"  #FQDN of the sub domain
$APIVer = "/2012-12-12"  #AWS may change in the future needs to have "/" before numbers
######################################################################


###Resources###
###Probably will not ever change###
Set-Variable -Name AwsKeyID -Value $env:AwsDNSAccessKeyID -Scope Global
Set-Variable -Name secretkey -Value $env:AwsDNSSecretKey -Scope Global
Set-Variable -Name zoneID -Value $env:AwsZoneID -Scope Global #Zone ID from AWS
Set-Variable -Name HeaderDictionary -Value (new-object "System.Collections.Generic.Dictionary``2[[System.String, mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089],[System.String, mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089]]") -Scope Global
$server = "https://route53.amazonaws.com"
$resourceURL = "/hostedzone/"  
$endpoint = "/rrset?"
$postEndpoint = "/rrset"
$ZoneOrigin = "."
$ZoneExists = $false
#######################################################################

######TODO######
# 1) Need a way to clear out the header dictionary to support requests that may take longer
# 2) Refactoring
#
#
#
#######################################################################

function GetTimeStamp() {
	try {
	#Try to get the date from AWS Route 53 first
	Set-Variable -Name AwsTime -Value (Invoke-WebRequest -uri https://route53.amazonaws.com/date)
	#If No Response use system time.
	Set-Variable -Name date -Value ($AwsTime.Headers.Date) -Scope Global
	}
	catch {
	#If the Route 53 servers fail to respond set the date to the local system date
	Set-Variable -Name date -Value (Get-Date -Format r) -Scope Global 
	}
	return $date
}


function SignRequest ([string]$d, [string]$k){
	###Sign AWS request with AWS Secret Key###
	###Adapted from Nerd Words http://nerdwords.blogspot.com/2012_02_01_archive.html ###
	$hmacsha = New-Object System.Security.Cryptography.HMACSHA256
	$utf8 = New-Object System.Text.utf8encoding
	$hmacsha.key =  $utf8.Getbytes($k)
	$seedBytes = $utf8.GetBytes($d)
	$digest = $hmacsha.ComputeHash($seedBytes)
	$base64Encoded = [Convert]::Tobase64String($digest)
return $base64Encoded
}

function CreateHeaders ($s) {
	###Create AWS Required request Headers###
	$HeaderDictionary.Add("x-amz-date", $date)
	$HeaderDictionary.Add("x-amzn-authorization", "AWS3-HTTPS AWSAccessKeyId=$AwsKeyID,Algorithm=HmacSHA256,Signature=$S")
}

#####Signature debugger#####
#function DebugSig() {
#$Time = GetTimeStamp
#$Sig = SignRequest $Time $secretKey
#return $Sig
#}
#$Signature = DebugSig


##Show request URL
#write-host "Service URL hit: " $listzoneURI
###################



###Contact http://icanhazip.com to get current IP address####
function GetIP() {
	$PublicIP = Invoke-Webrequest -Uri "http://icanhazip.com" -Method get
	$PublicIP = $PublicIP.Content.ToString()
	$PublicIP = $PublicIP.TrimEnd()
return $PublicIP
}

function CreateRecord() {
$HostIP = GetIp
####debugging####
Write-Host "Public IP is: " $HostIP
#################
$BuildZoneRequest = @"
<?xml version="1.0" encoding="UTF-8"?>
<ChangeResourceRecordSetsRequest xmlns="https://route53.amazonaws.com/doc$APIVer/">
<ChangeBatch>
<Comment>Created with R53DynDns</Comment>
<Changes>
<Change>
<Action>CREATE</Action>
<ResourceRecordSet>
<Name>$DynamicSubzone</Name>
<Type>A</Type>
<TTL>300</TTL>
<ResourceRecords>
<ResourceRecord>
<Value>$HostIP</Value>
</ResourceRecord>
</ResourceRecords>
</ResourceRecordSet>
</Change>
</Changes>
</ChangeBatch>
</ChangeResourceRecordSetsRequest>
"@
return $BuildZoneRequest
}

function DeleteOldRecord($oip, $hip){
Write-Host "Building modify request"
$BuildDeleteRequest = @"
<?xml version="1.0" encoding="UTF-8"?>
<ChangeResourceRecordSetsRequest xmlns="https://route53.amazonaws.com/doc$APIVer/">
<ChangeBatch>
<Comment></Comment>
<Changes>
<Change>
<Action>DELETE</Action>
<ResourceRecordSet>
<Name>$DynamicSubzone</Name>
<Type>A</Type>
<TTL>300</TTL>
<ResourceRecords>
<ResourceRecord>
<Value>$oip</Value>
</ResourceRecord>
</ResourceRecords>
</ResourceRecordSet>
</Change>
<Change>
<Action>CREATE</Action>
<ResourceRecordSet>
<Name>$DynamicSubzone</Name>
<Type>A</Type>
<TTL>300</TTL>
<ResourceRecords>
<ResourceRecord>
<Value>$hip</Value>
</ResourceRecord>
</ResourceRecords>
</ResourceRecordSet>
</Change>
</Changes>
</ChangeBatch>
</ChangeResourceRecordSetsRequest>
"@

return $BuildDeleteRequest

}



function CreateZoneRecord() {
	$Request = CreateRecord
	$ZoneBuildURI = $server + $APIVer + $resourceURL + $zoneID + $postEndpoint
    #####Debugging#####
	#Write-Host "XML Requst to AWS:`n"$Request
    #Write-Host "Request Create URL:`n"$ZoneBuildURI

    ####Send Create Zone Request####
    Write-Host "Sending request to AWS"
    [xml]$ZoneBuildRequest = Invoke-RestMethod -URI $ZoneBuildURI -method post -ContentType "text/xml" -Headers $HeaderDictionary -Body $Request

	$CreateZone = "" | Select-Object -Property ChangeID,ChangeStatus
	$CreateZone.ChangeID = $ZoneBuildRequest.ChangeResourceRecordSetsResponse.ChangeInfo.ID
	$CreateZone.ChangeStatus = $ZoneBuildRequest.ChangeResourceRecordSetsResponse.ChangeInfo.Status

	Write-Host "ChangeID: " $CreateZone.ChangeID
	Write-Host "Status: " $CreateZone.ChangeStatus
	
	return $CreateZone
}

function GetZoneList() {
	$Time = GetTimeStamp
	$Sign = SignRequest $Time $secretKey
	$Headers = CreateHeaders $Sign
	$listzoneURI = $server + $APIVer + $resourceURL + $zoneID + $endpoint
	###Send REST request to ASW and save response###
	[xml]$response = Invoke-WebRequest -URI $listzoneURI -method get -ContentType "text/xml" -Headers $HeaderDictionary

	$zones = $response.ListResourceRecordSetsResponse.ResourceRecordSets.ResourceRecordSet
return $zones
}


function CheckForZone() {
	$zones = GetZoneList
	Write-Host "Checking for " $DynamicSubzone$ZoneOrigin
	foreach ($zone in $zones){
		#Write-Host $zone.Name $zone.Type $zone.Value $zone.TTL
		if (($zone.Name -eq $DynamicSubzone + $ZoneOrigin) -and ($zone.Type -eq "A")) {
		
        	 $ZoneExists = $true
			 return $ZoneExists
    	}
		else {
			$ZoneExists = $false
		}
	}
	return $ZoneExists
}

function CheckChangeStatus($cid) {
	Write-Host "Checking Status"
	$timeout = new-timespan -Minutes 2 -Seconds 30
	$sw = [diagnostics.stopwatch]::StartNew()
	$UpdatePending = $true	
		
		while ($UpdatePending){
			if ($sw.elapsed -lt $timeout){

				$CheckURI = $server + $APIVer + $cid
				#####Debugging#######
				#Write-Host "Checking URI "$CheckURI
				#####################
				[xml]$Status = Invoke-RestMethod -Uri $CheckURI -method get -ContentType "text/xml" -Headers $HeaderDictionary
				####State is what is needed to be PENDING or INSYNC. Needs and IF statement.
				$State = $Status.GetChangeResponse.ChangeInfo.status 
					if ($State -eq "INSYNC") {
						Write-Host "Zone is Synced"
						$UpdatePending = $false
					}
					else {
						Write-Host "Sync pending"
						Start-Sleep -Seconds 10
					}
			}
			elseif ($sw.elapsed -gt $timeout){
				 $UpdatePending = $false
				 Write-Host "A timeout has occured while waiting for zone sync status.`nCheck the AWS Route 53 Management Console to find out the status of the requested change.`nChangeID: " $cid
				 
			}
		}
}

function UpdateIP(){
	Write-Host "Runing update function"
	$HostIP = GetIp
	$listzoneURI = $server + $APIVer + $resourceURL + $zoneID + $endpoint
	[xml]$response = Invoke-WebRequest -URI $listzoneURI -method get -ContentType "text/xml" -Headers $HeaderDictionary
	$recordNode = $response.ListResourceRecordSetsResponse.ResourceRecordSets.ResourceRecordSet | Where {$_.Name -eq $DynamicSubzone+$ZoneOrigin}
	$IP = $recordNode.ResourceRecords.ResourceRecord.Value 
	if ($IP -eq $HostIP) {
		Write-Host "IP is the same. Nothing to do"
		$DeleteZone = "" | Select-Object -Property ChangeID,ChangeStatus
		$DeleteZone.ChangeID = $null
		$DeleteZone.ChangeStatus = $null
	}
	else {
		Write-Host "Updating IP"
		########BuildFunctionToUpdateIP######
		$delete = DeleteOldRecord $IP $HostIP
		$ZoneDeleteURI = $server + $APIVer + $resourceURL + $zoneID + $postEndpoint 
		[xml]$ZoneDeleteRequest = Invoke-RestMethod -URI $ZoneDeleteURI -method post -ContentType "text/xml" -Headers $HeaderDictionary -Body $delete
		$DeleteZone = "" | Select-Object -Property ChangeID,ChangeStatus
		$DeleteZone.ChangeID = $ZoneDeleteRequest.ChangeResourceRecordSetsResponse.ChangeInfo.ID
		$DeleteZone.ChangeStatus = $ZoneDeleteRequest.ChangeResourceRecordSetsResponse.ChangeInfo.Status

		Write-Host "ChangeID: " $DeleteZone.ChangeID
		Write-Host "Status: " $DeleteZone.ChangeStatus
	
	
	}
	return $DeleteZone
}


$ZoneCheck = CheckForZone
	if ($ZoneCheck) {
		Write-Host "Zone Exists"
		$ModifyZone = UpdateIP
		if ($ModifyZone.ChangeID -eq $null) {
			Write-Host "Zone is current."
		}
		else {
			CheckChangeStatus $ModifyZone.ChangeID
		}
	}
	else {
		Write-Host "Zone does not exist"
		$BuildZone = CreateZoneRecord 
		CheckChangeStatus $BuildZone.ChangeID
	}