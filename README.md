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
