# SystemLog & Device Posture – GetRecords

PowerShell script to retrieve **System Logs** and **Device Posture** data from **Citrix Cloud** and save them as JSON.

- **Script:** `logs_systemXdevicePosture.ps1`  
- **Output:** Timestamped JSON files in `./CitrixLogs`  
- **Errors:** Written to `./errors.log` (with timestamps)

---

## Features
- Decrypts credentials from an encoded `creds.csv`.
- Authenticates via **Service Principal** (client-credentials flow).
- Retrieves a **Bearer token**.
- Queries **System Log** (REST) and **Device Posture** (GraphQL).
- Stores responses as JSON files.

## Requirements & Permissions
Service principal must have:
- **General → System Log**  
- **Endpoint Management → Device provisioning**

## Notes
- Targets **EU endpoints** by default; adjust URLs for other regions.
- `creds.csv` (same folder as the script) must contain encoded values for:
  - `Client-ID`
  - `Secret`
  - `Customer-ID`

## Endpoints (EU)
- **Bearer token:** `https://api-eu.cloud.com/cctrustoauth2/<Customer-ID>/tokens/clients`  
- **System Log API:** `https://api-eu.cloud.com/systemlog/records`  
- **Device Posture (GraphQL):** `https://dashboard.netscalergateway.net/graphql`

---

_Coded by `TrinityCode@Bechtle`_
