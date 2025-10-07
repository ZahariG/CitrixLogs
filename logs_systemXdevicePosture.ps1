# ################### SystemLog & DevicePosture - GetRecords ################### 
#
# Script:       logs_systemXdevicePosture.ps1
# Description:  This PowerShell script retrieves System Logs and Device Posture Logs 
#               from the Citrix Cloud APIs and saves them as JSON files.
#
# Functionality:
#       - Decrypts credentials stored in an encoded CSV file.
#       - Authenticates via a Citrix Cloud service principal using client credentials flow.
#       - Retrieves a bearer token from Citrix Cloud.
#       - Queries System Log records from the SystemLog API.
#       - Queries Device Posture data using the GraphQL API endpoint.
#       - Stores all responses as timestamped JSON files inside the "CitrixLogs" folder.
#       - Logs errors to `errors.log` with timestamps.
#
# Requirements:
#       - The service principal used for authentication must have the following permissions:
#           > General -> System Log  
#           > Endpoint Management -> Device provisioning
#
# Note:
#       - This script targets the EU endpoints. You may adjust the URLs for other regions.
#       - Ensure `creds.csv` exists in the script directory (with encoded values) for:
#           > Client-ID
#           > Secret
#           > Customer-ID
#
#   Coded by TrinityCode@Bechtle
#################################################################################

#                               ############# FUNCTIONS ############
# # WRITE ERRORS TO errors.log
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$message
    )

    $path = "./errors.log"
    if (-Not (Test-Path $path)) {
        New-Item -Path "./" -Name "errors.log" -ItemType "File"
    }

    $timestamp = (Get-Date).ToString("yyyy.MM.dd-HH:mm:ss >> ")
    
    Add-Content -Path $path -Value "$timestamp$message"
}
# # GET THE BEARER-TOKEN
function Get-BearerToken {
    param (
        [Parameter(Mandatory = $true)]
        [string]$clientID,
        [Parameter(Mandatory = $true)]
        [string]$clientSecret,
        [Parameter(Mandatory = $true)]
        [string]$bearerTokenUrl
    )
    $headers = @{
        "Accept"       = "application/json"
        "Content-Type" = "application/x-www-form-urlencoded"
    }

    $body = @{        
        "grant_type"    = "client_credentials"
        "client_id"     = $clientID
        "client_secret" = $clientSecret
    }

    try {
        $response = Invoke-RestMethod `
            -Headers $headers `
            -Method POST `
            -Uri $bearerTokenUrl `
            -Body $body `
            -ContentType "application/x-www-form-urlencoded"

        if ($response -and $response.access_token) {
            return $response.access_token
        }
        else {
            Write-Log "Bearer Access-Token empty!"
            return $null
        }
    }
    catch {
        Write-Log "$( $_.Exception.Message )`nCould not get bearer token. Abort..."
        
        if ($_.Exception.Response) {
            $status = ($_.Exception.Response).StatusCode
            Write-Log "HTTP-Statuscode: $status"
        } 
        exit 1
    }
}
# # GET THE SYSTEM-LOGS
function Get-SystemLogRecords {
    param(
        [Parameter(Mandatory = $true)]
        [string]$customerID,
        [Parameter(Mandatory = $true)]
        [string]$bearerToken,
        [Parameter(Mandatory = $true)]
        [string]$systemLogUrl,
        [Parameter(Mandatory = $true)]
        [string]$date,
        [Parameter(Mandatory = $true)]
        [string]$startTime,
        [Parameter(Mandatory = $true)]
        [string]$endTime
    )

    $headers = @{
        "Accept"            = "application/json"
        "Authorization"     = "CwsAuth Bearer=$bearerToken"
        "Citrix-CustomerId" = $customerID
        # "Accept-Charset"        = "utf-8" #(optional)
        # "Citrix-TransactionId"  = ""  #(optional)
    }

    $systemLogQueryUrl = "${systemLogUrl}?startDateTime=${date}T${startTime}Z&endDateTime=${date}T${endTime}Z&limit=200"

    try {
        $response = Invoke-RestMethod `
            -Method GET `
            -Uri $systemLogQueryUrl `
            -Headers $headers `

        if ($response) {
            return $response
        }
        else {
            Write-Log "System-Logs were empty!"
            return $null
        }
    }
    catch {
        Write-Log "$( $_.Exception.Message )`nCould not get System-Logs. Abort..."
        
        if ($_.Exception.Response) {
            $status = ($_.Exception.Response).StatusCode
            Write-Log "HTTP-Statuscode: $status"
        } 
        return $null
    }
}
# # GET THE DEVICEPOSTURE-LOGS
function Get-DevicePostureRecords {

    param (
        [Parameter(Mandatory = $true)]
        [string]$customerID,
        [Parameter(Mandatory = $true)]
        [string]$bearerToken,
        [Parameter(Mandatory = $true)]
        [string]$devicePostureUrl,
        [Parameter(Mandatory = $true)]
        [string]$date,
        [Parameter(Mandatory = $true)]
        [string]$startTime,
        [Parameter(Mandatory = $true)]
        [string]$endTime
    )

    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    # $session.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36"

    $payload = [pscustomobject]@{
        operationName = "DevicePostureLogsReport"
        variables     = @{
            where   = @{
                AND            = @(
                    @{ source = "Device Posture Service" }
                    @{ tenant_id_contains = "%%" }
                )
                __time_between = "$date" + "T" + "$startTime" + "Z,$date" + "T" + "$endTime" + "Z"
            }
            limit   = 10000
            orderBy = @("__time_DESC")
        }
        query         = 'query DevicePostureLogsReport($where: SwaAppLaunchLogsWhereInput, $limit: Int, $orderBy: [SwaAppLaunchLogsOrderByInput]) {
    data: swaAppLaunchLogs(where: $where, limit: $limit, orderBy: $orderBy) {
      __time userName successOrFailure policyInfo OS transactionId publicIP infoCode infoCodeDescription deviceId additionalDetail
    }
    logsCount: swaAppLaunchLogs(where: $where) { record_cnt __typename }
  }'
    }

    $body = $payload | ConvertTo-Json -Depth 5

    try {
        $response = Invoke-RestMethod `
            -Uri $devicePostureUrl `
            -Method Post `
            -WebSession $session `
            -Headers @{
            "Accept"            = "application/json"
            "Accept-Encoding"   = "gzip, deflate, br, zstd"
            "Accept-Language"   = "de-DE,de;q=0.9,en-US;q=0.8,en;q=0.7"
            "DNT"               = "1"
            "Origin"            = "https://device-posture-config.cloud.com"
            "Authorization"     = "CWSAuth bearer=$bearerToken"
            "Citrix-CustomerId" = $customerID
            "Geolocation"       = "US"
        } `
            -ContentType "application/json" `
            -Body $body

        if ($response) {
            return $response
        }
        else {
            Write-Log "Response from DevicePosture-Log was empty!"
            return $null
        }

    }
    catch {
        Write-Log "$( $_.Exception.Message )`nCould not get DevicePosture-Logs. Abort..."
        
        if ($_.Exception.Response) {
            $status = ($_.Exception.Response).StatusCode
            Write-Log "HTTP-Statuscode: $status"
        } 
        return $null
    }
}
# # DECRYPT CREDENTIALS FROM creds.csv
function Get-StringToDecrypt {
    param(
        [Parameter (Mandatory = $true)][string]$string
    )       

    $bArrayB64 = [System.Convert]::FromBase64String($string)

    return [System.Text.Encoding]::UTF8.GetString($bArrayB64)
}
#                                       ############ - FUNCTIONS END - ##############
#############################################
#                                           ############# MAIN ############
## IMPORTING CREDENTIALS ##
$credentials = Import-Csv -Path "./creds.csv"
foreach ($row in $credentials) {
    $clientID = Get-StringToDecrypt -string ($row."Client-ID")
    $clientSecret = Get-StringToDecrypt -string ($row."Secret")
    $customerID = Get-StringToDecrypt -string ($row."Customer-ID")
}

## URLS ##
$bearerTokenUrl = "https://api-eu.cloud.com/cctrustoauth2/$customerID/tokens/clients"
# $systemLogUrl =  "https://api-us.cloud.com/systemlog/records"   # Global
$systemLogUrl = "https://api-eu.cloud.com/systemlog/records"     # EU
$devicePostureUrl = "https://dashboard.netscalergateway.net/graphql"

## START & ENDDATE + TIME ##
$date = (Get-Date).AddDays(-1).ToString("yyyy-MM-dd")
$startTime = "00:00:00.000"
$endTime = "23:59:59.999"

## FILE NAMING & PATHING ##
$pathToLogs = "./CitrixLogs"
if (-Not (Test-Path $pathToLogs)) {
    try {
        New-Item -Path $pathToLogs -ItemType "Directory" -Force | Out-Null
    }
    catch {
        Write-Log "Folder 'APIlogs' could not be created.`n$($_.Exception.Message)"
        exit 1
    }
}
$timestampFile = (Get-Date).ToString("yyyy-MM-ddTHH-mm-ss")
$sysLogjsonName = "SystemLog_${timestampFile}.json"
$dpLogjsonName = "DevicePosture_${timestampFile}.json"
$sysLogjsonPath = "${pathToLogs}/${sysLogjsonName}"
$dpLogjsonPath = "${pathToLogs}/${dpLogjsonName}"

## GET THE BEARER TOKEN
$bearerToken = Get-BearerToken $clientID $clientSecret $bearerTokenUrl

## CALL THE NEEDE FUNCTIONS TO GET THE NEEDED LOGS
Get-SystemLogRecords $customerID $bearerToken $systemLogUrl $date $startTime $endTime | ConvertTo-Json -Depth 10 | Set-Content -Path $sysLogjsonPath

Get-DevicePostureRecords $customerID $bearerToken $devicePostureUrl $date $startTime $endTime | ConvertTo-Json -Depth 10 | Set-Content -Path $dpLogjsonPath