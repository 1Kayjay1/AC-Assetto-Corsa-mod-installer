<#
.SYNOPSIS
    Assetto Corsa Mod Installer v2.0
    Smart detection, atomic folder handling, and undo capability.

.DESCRIPTION
    Analyzes mod folders to determine installation paths.
    Prioritizes standard AC folder structures (content, apps, extension).
    Handles "atomic" mod units (cars, tracks, apps) to prevent file fragmentation.
    Provides backup and undo functionality.
#>

Add-Type -AssemblyName System.Windows.Forms

# --- Configuration ---
$ConfigPath = Join-Path $PSScriptRoot "ac_install_config.txt"
$Global:IncludedPaths = @() # Tracks paths handled by structural detection

# --- Helper Functions ---

function Log-Message {
    param (
        [string]$Message,
        [ConsoleColor]$Color = "White"
    )
    Write-Host "[$([DateTime]::Now.ToString('HH:mm:ss'))] $Message" -ForegroundColor $Color
}

function Get-FolderSelection {
    param (
        [string]$Description,
        [string]$SelectedPath
    )

    # Option 1: Paste Path
    Write-Host "$Description" -ForegroundColor Cyan
    $InputPath = Read-Host "Paste folder path here (or press Enter to browse)"
    $InputPath = $InputPath -replace '"', ''

    if ($InputPath) {
        if (Test-Path $InputPath) {
            if (Test-Path $InputPath -PathType Container) {
                return $InputPath
            } else {
                Write-Host "Path is a file. Using parent directory." -ForegroundColor Yellow
                return Split-Path $InputPath -Parent
            }
        } else {
            Write-Host "Path not found. Opening browser..." -ForegroundColor Yellow
            Start-Sleep -Milliseconds 500
        }
    }

    # Option 2: Folder Browser
    $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $FolderBrowser.Description = $Description
    $FolderBrowser.ShowNewFolderButton = $false
    if ($SelectedPath -and (Test-Path $SelectedPath)) { $FolderBrowser.SelectedPath = $SelectedPath }

    $Result = $FolderBrowser.ShowDialog()
    if ($Result -eq [System.Windows.Forms.DialogResult]::OK) {
        return $FolderBrowser.SelectedPath
    }
    return $null
}

function Mark-Included {
    param([string]$Path)
    $Global:IncludedPaths += $Path
}

function Test-IsIncluded {
    param([string]$Path)
    foreach ($p in $Global:IncludedPaths) {
        if ($Path.StartsWith($p) -or $Path -eq $p) { return $true }
    }
    return $false
}

# --- Detection Logic ---

function Get-InstallPlan {
    param($SourceRoot, $ACRoot)
    
    $Plan = @()
    $Global:IncludedPaths = @()

    Log-Message "Scanning structure..." "Cyan"

    # --- Phase 1: Standard Folder Structure (Atomic Units) ---
    # We look for specific known folders in the source and map them to AC root.
    
    # 1. Content (Cars, Tracks, etc.)
    $ContentMap = @{
        "content\cars" = "Car";
        "content\tracks" = "Track";
        "content\showroom" = "Showroom";
        "content\driver" = "Driver";
        "content\fonts" = "Font";
        "content\gui" = "GUI";
        "content\weather" = "Weather";
        "content\sfx" = "SFX"
    }

    foreach ($RelPath in $ContentMap.Keys) {
        $SourcePath = Join-Path $SourceRoot $RelPath
        if (Test-Path $SourcePath) {
            # Get immediate children (e.g., individual car folders)
            $Children = Get-ChildItem $SourcePath -Directory
            foreach ($Child in $Children) {
                $Plan += [PSCustomObject]@{
                    Type = $ContentMap[$RelPath]
                    Name = $Child.Name
                    Source = $Child.FullName
                    Destination = Join-Path $ACRoot $RelPath | Join-Path -ChildPath $Child.Name
                    IsFolder = $true
                }
                Mark-Included $Child.FullName
            }
            # Also handle loose files in these folders if necessary (usually not for cars/tracks, but maybe others)
             $Files = Get-ChildItem $SourcePath -File
             foreach ($File in $Files) {
                 # Loose files in content/cars are rare/wrong, but we handle generic merges later.
                 # For now, we only care about atomic folders.
             }
        }
    }

    # 2. Apps (Python, Lua)
    $AppMap = @{
        "apps\python" = "App (Python)";
        "apps\lua" = "App (Lua)"
    }
    foreach ($RelPath in $AppMap.Keys) {
        $SourcePath = Join-Path $SourceRoot $RelPath
        if (Test-Path $SourcePath) {
            $Children = Get-ChildItem $SourcePath -Directory
            foreach ($Child in $Children) {
                $Plan += [PSCustomObject]@{
                    Type = $AppMap[$RelPath]
                    Name = $Child.Name
                    Source = $Child.FullName
                    Destination = Join-Path $ACRoot $RelPath | Join-Path -ChildPath $Child.Name
                    IsFolder = $true
                }
                Mark-Included $Child.FullName
            }
        }
    }

    # 3. Extension (Config, Lua Tools, Textures)
    # Extension is complex. Some are atomic tools, some are loose config files.
    
    # Atomic Tools
    $ExtToolMap = @{
        "extension\lua\tools" = "CSP Tool";
        "extension\lua\joypad-assist" = "CSP Assist";
        "extension\lua\chaser-camera" = "CSP Camera";
        "extension\lua\new-modes" = "CSP Mode";
        "extension\weather" = "CSP Weather";
        "extension\weather-controllers" = "CSP Weather Controller"
    }
    foreach ($RelPath in $ExtToolMap.Keys) {
        $SourcePath = Join-Path $SourceRoot $RelPath
        if (Test-Path $SourcePath) {
            $Children = Get-ChildItem $SourcePath -Directory
            foreach ($Child in $Children) {
                $Plan += [PSCustomObject]@{
                    Type = $ExtToolMap[$RelPath]
                    Name = $Child.Name
                    Source = $Child.FullName
                    Destination = Join-Path $ACRoot $RelPath | Join-Path -ChildPath $Child.Name
                    IsFolder = $true
                }
                Mark-Included $Child.FullName
            }
        }
    }

    # --- Phase 2: Root Level Detection (Standalone Mods) ---
    # Check if the SourceRoot ITSELF is a car or track
    
    if (Test-Path (Join-Path $SourceRoot "ui_car.json")) {
        $DirName = Split-Path $SourceRoot -Leaf
        $Plan += [PSCustomObject]@{
            Type = "Car"
            Name = $DirName
            Source = $SourceRoot
            Destination = Join-Path $ACRoot "content\cars\$DirName"
            IsFolder = $true
        }
        Mark-Included $SourceRoot
        return $Plan # If root is a car, we are done
    }
    
    if (Test-Path (Join-Path $SourceRoot "ui_track.json")) {
        $DirName = Split-Path $SourceRoot -Leaf
        $Plan += [PSCustomObject]@{
            Type = "Track"
            Name = $DirName
            Source = $SourceRoot
            Destination = Join-Path $ACRoot "content\tracks\$DirName"
            IsFolder = $true
        }
        Mark-Included $SourceRoot
        return $Plan
    }

    # Check immediate subfolders for standalone cars/tracks (common in unzipped packs)
    $RootDirs = Get-ChildItem $SourceRoot -Directory
    foreach ($Dir in $RootDirs) {
        if (Test-IsIncluded $Dir.FullName) { continue }

        if (Test-Path (Join-Path $Dir.FullName "ui_car.json")) {
            # It's a car folder
            $Plan += [PSCustomObject]@{
                Type = "Car"
                Name = $Dir.Name
                Source = $Dir.FullName
                Destination = Join-Path $ACRoot "content\cars\$($Dir.Name)"
                IsFolder = $true
            }
            Mark-Included $Dir.FullName
        }
        elseif (Test-Path (Join-Path $Dir.FullName "ui_track.json")) {
            # It's a track folder
            $Plan += [PSCustomObject]@{
                Type = "Track"
                Name = $Dir.Name
                Source = $Dir.FullName
                Destination = Join-Path $ACRoot "content\tracks\$($Dir.Name)"
                IsFolder = $true
            }
            Mark-Included $Dir.FullName
        }
        elseif (Test-Path (Join-Path $Dir.FullName "ui\ui_track.json")) {
             # Track folder structure: TrackName/ui/ui_track.json
            $Plan += [PSCustomObject]@{
                Type = "Track"
                Name = $Dir.Name
                Source = $Dir.FullName
                Destination = Join-Path $ACRoot "content\tracks\$($Dir.Name)"
                IsFolder = $true
            }
            Mark-Included $Dir.FullName
        }
    }

    # --- Phase 3: Generic Root Merge & File Detection ---
    # Walk the tree. If a folder matches a root AC folder, merge it.
    # If a file is encountered, classify it.

    $ACRootFolders = @("content", "apps", "system", "extension", "launcher", "driver", "fonts", "weather", "gui", "plugins", "reshade-shaders")
    
    # 3a. Merge known root folders
    foreach ($Folder in $ACRootFolders) {
        $SourcePath = Join-Path $SourceRoot $Folder
        if (Test-Path $SourcePath) {
            # We want to merge the CONTENTS of this folder, not the folder itself necessarily, 
            # but we need to respect the atomic units we already marked.
            
            # Get all files recursively in this root folder
            $AllFiles = Get-ChildItem $SourcePath -Recurse -File
            foreach ($File in $AllFiles) {
                if (-not (Test-IsIncluded $File.FullName)) {
                    # This file is NOT part of an atomic unit (car/track/app) we already handled.
                    # It needs to be merged individually or as part of a subfolder.
                    
                    # Calculate relative path from SourceRoot
                    $RelPath = $File.FullName.Substring($SourceRoot.Length + 1)
                    
                    $Plan += [PSCustomObject]@{
                        Type = "Root Merge"
                        Name = $RelPath
                        Source = $File.FullName
                        Destination = Join-Path $ACRoot $RelPath
                        IsFolder = $false
                    }
                }
            }
        }
    }

    # 3b. Loose Files at Root (or non-standard folders)
    $LooseItems = Get-ChildItem $SourceRoot -Recurse
    foreach ($Item in $LooseItems) {
        if ($Item.PSIsContainer) { continue } # Skip folders, we handle files
        if (Test-IsIncluded $Item.FullName) { continue } # Skip if already handled
        
        # Check if it was handled by 3a (Root Merge)
        $IsRootMerge = $false
        foreach ($RootF in $ACRootFolders) {
            if ($Item.FullName.StartsWith((Join-Path $SourceRoot $RootF))) { $IsRootMerge = $true; break }
        }
        if ($IsRootMerge) { continue }

        # It's a loose file not in a standard root folder. Classify it.
        $Classification = Identify-File -FilePath $Item.FullName -ModRoot $SourceRoot
        
        if ($Classification) {
            $Dest = $null
            if ($Classification.Preserve) {
                # Try to preserve relative structure if it makes sense, otherwise specific dest
                $Dest = $Classification.Dest # Usually specific for loose files
            } else {
                $Dest = $Classification.Dest
            }

            if ($Dest) {
                $Plan += [PSCustomObject]@{
                    Type = $Classification.Type
                    Name = $Item.Name
                    Source = $Item.FullName
                    Destination = $Dest
                    IsFolder = $false
                }
            }
        }
    }

    return $Plan
}

function Identify-File {
    param($FilePath, $ModRoot)
    
    $FileName = Split-Path $FilePath -Leaf
    $Ext = [System.IO.Path]::GetExtension($FilePath).ToLower()
    $Content = Get-Content -Path $FilePath -TotalCount 50 -ErrorAction SilentlyContinue | Out-String
    
    # --- INI Files ---
    if ($Ext -eq ".ini") {
        # Track Configs (Context Aware)
        # If the file is in a 'data' folder, it's likely a car or track config, NOT a PP filter
        if ($FilePath -match "\\data\\") {
             # We assume if it's in a 'data' folder and hasn't been caught by atomic detection, 
             # it might be a loose config update.
             # But strictly, 'ai_hints.ini' is track data.
             if ($FileName -in @("ai_hints.ini", "surfaces.ini", "map.ini", "audio_sources.ini", "models.ini", "cameras.ini")) {
                 # It's a track config. But where does it go? 
                 # Without a known track context, we can't install it safely unless we preserve path.
                 # If it's loose in root, we can't install it.
                 return $null 
             }
        }

        # PP Filters
        if ($Content -match "\[PP_BUILD\]" -or $Content -match "\[POST_PROCESS\]") {
            return @{ Type = "PP Filter"; Dest = Join-Path $ACPath "system\cfg\ppfilters\$FileName" }
        }
        
        # CSP Configs
        if ($Content -match "\[SHADER_REPLACEMENT_...\]" -or $Content -match "\[ext_config\]") {
             return @{ Type = "CSP Config"; Dest = Join-Path $ACPath "extension\config\$FileName" }
        }
    }

    # --- Lua Files ---
    if ($Ext -eq ".lua") {
        # Pure Scripts
        # Must NOT be in an app folder (already handled by atomic check, but double check)
        if ($FilePath -notmatch "apps\\" -and $FilePath -notmatch "extension\\") {
            if ($Content -match "--.*Pure" -or $Content -match "ac\." -or $FilePath -match "pure_scripts") {
                 return @{ Type = "Pure Script"; Dest = Join-Path $ACPath "system\cfg\ppfilters\pure_scripts\$FileName" }
            }
        }
    }

    # --- JSON Files ---
    if ($Ext -eq ".json") {
        if ($FileName -eq "traffic.json") {
             # Traffic config. Needs track context. If loose, ignore or warn.
             return $null
        }
    }

    return $null
}

# --- Main Execution ---

# 1. AC Path
$ACPath = $null
if (Test-Path $ConfigPath) { $ACPath = Get-Content $ConfigPath -Raw; $ACPath = $ACPath.Trim() }

if (-not $ACPath -or -not (Test-Path $ACPath)) {
    $ACPath = Get-FolderSelection -Description "Select Assetto Corsa Root Folder"
    if (-not $ACPath) { exit }
    Set-Content -Path $ConfigPath -Value $ACPath
}
Log-Message "AC Path: $ACPath" "Green"

# 2. Mod Path / Archive
Write-Host "Select Mod (Folder or Archive)" -ForegroundColor Cyan
Add-Type -AssemblyName System.Windows.Forms
$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog
$FileBrowser.Filter = "Mod Files (*.zip;*.rar;*.7z)|*.zip;*.rar;*.7z|All Files (*.*)|*.*"
$FileResult = $FileBrowser.ShowDialog()

$ModPath = $null
$IsArchive = $false
$TempPath = $null

if ($FileResult -eq [System.Windows.Forms.DialogResult]::OK) {
    $ModPath = $FileBrowser.FileName
    $IsArchive = $true
} else {
    $ModPath = Get-FolderSelection -Description "Select Mod Folder"
}

if (-not $ModPath) { exit }

# 3. Extract if Archive
if ($IsArchive) {
    $TempPath = Join-Path $env:TEMP "AC_Mod_Extract_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $TempPath -Force | Out-Null
    Log-Message "Extracting to $TempPath..." "Yellow"
    
    $Ext = [System.IO.Path]::GetExtension($ModPath).ToLower()
    if ($Ext -eq ".zip") { Expand-Archive $ModPath $TempPath -Force }
    elseif ($Ext -eq ".rar") { 
        # Simple WinRAR check
        $WinRar = "C:\Program Files\WinRAR\WinRAR.exe"
        if (Test-Path $WinRar) { & $WinRar x -ibck -y "$ModPath" "$TempPath\" }
        else { Write-Host "WinRAR not found." -ForegroundColor Red; exit }
    }
    elseif ($Ext -eq ".7z") {
        # Simple 7Zip check
        $7z = "C:\Program Files\7-Zip\7z.exe"
        if (Test-Path $7z) { & $7z x "-o$TempPath" -y "$ModPath" }
        else { Write-Host "7-Zip not found." -ForegroundColor Red; exit }
    }
    
    # Handle single folder nesting
    $Items = Get-ChildItem $TempPath
    if ($Items.Count -eq 1 -and $Items[0].PSIsContainer) {
        $ModPath = $Items[0].FullName
    } else {
        $ModPath = $TempPath
    }
}

# 4. Analyze
$Plan = Get-InstallPlan -SourceRoot $ModPath -ACRoot $ACPath

if ($Plan.Count -eq 0) {
    Log-Message "No installable content found." "Red"
    if ($IsArchive) { Remove-Item $TempPath -Recurse -Force }
    Read-Host "Press Enter"
    exit
}

# 5. Review & Conflict Resolution
# Group by destination to find conflicts
$Groups = $Plan | Group-Object Destination

$FinalPlan = @()

foreach ($Group in $Groups) {
    if ($Group.Count -gt 1) {
        Write-Host "`n[!] CONFLICT: Multiple sources for $($Group.Name)" -ForegroundColor Red
        for ($i=0; $i -lt $Group.Group.Count; $i++) {
            Write-Host "$($i+1). [$($Group.Group[$i].Type)] $($Group.Group[$i].Name)"
        }
        $Choice = Read-Host "Select source (1-$($Group.Group.Count))"
        $FinalPlan += $Group.Group[[int]$Choice - 1]
    } else {
        $FinalPlan += $Group.Group[0]
    }
}

# Display Plan
Write-Host "`n--- INSTALLATION PLAN ---" -ForegroundColor Cyan
if ($FinalPlan.Count -gt 50) {
    $FinalPlan | Group-Object Type | Format-Table Count, Name -AutoSize
    Write-Host "`n(Showing first 20 items...)" -ForegroundColor Gray
    $FinalPlan | Select-Object -First 20 | Format-Table Type, Name, Destination -AutoSize
} else {
    $FinalPlan | Format-Table Type, Name, Destination -AutoSize
}

$Confirm = Read-Host "Proceed? (Y/N)"
if ($Confirm -ne "Y") {
    if ($IsArchive) { Remove-Item $TempPath -Recurse -Force }
    exit
}

# 6. Install & Backup
$BackupPath = Join-Path $env:TEMP "AC_Mod_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
$InstalledLog = @()

Log-Message "Installing..." "Green"

foreach ($Item in $FinalPlan) {
    $DestDir = if ($Item.IsFolder) { $Item.Destination } else { Split-Path $Item.Destination -Parent }
    
    if (-not (Test-Path $DestDir)) { New-Item -ItemType Directory -Path $DestDir -Force | Out-Null }

    # Backup logic
    if ($Item.IsFolder) {
        # Folder merge/overwrite backup is complex. 
        # For atomic units (Cars/Tracks), we might be replacing or merging.
        # Simple backup: If destination exists, move it to backup? 
        # Or copy to backup.
        if (Test-Path $Item.Destination) {
            $BkpDest = Join-Path $BackupPath ($Item.Destination.Substring($ACPath.Length))
            New-Item -ItemType Directory -Path (Split-Path $BkpDest -Parent) -Force | Out-Null
            Copy-Item -Path $Item.Destination -Destination $BkpDest -Recurse -Force
        }
        Copy-Item -Path $Item.Source -Destination (Split-Path $Item.Destination -Parent) -Recurse -Force
    } else {
        # File backup
        if (Test-Path $Item.Destination) {
            $BkpDest = Join-Path $BackupPath ($Item.Destination.Substring($ACPath.Length))
            New-Item -ItemType Directory -Path (Split-Path $BkpDest -Parent) -Force | Out-Null
            Copy-Item -Path $Item.Destination -Destination $BkpDest -Force
        }
        Copy-Item -Path $Item.Source -Destination $Item.Destination -Force
    }
    
    $InstalledLog += @{ Dest = $Item.Destination; IsFolder = $Item.IsFolder }
}

Log-Message "Installation Complete." "Green"

# 7. Undo Prompt
Write-Host "`n[TESTING MODE]" -ForegroundColor Yellow
Write-Host "1. KEEP Changes (Delete Backup)"
Write-Host "2. UNDO Changes (Restore Backup)"
$Undo = Read-Host "Choice"

if ($Undo -eq "2") {
    Log-Message "Restoring..." "Yellow"
    # Restore logic
    # 1. Delete installed items
    foreach ($Log in $InstalledLog) {
        if (Test-Path $Log.Dest) { Remove-Item $Log.Dest -Recurse -Force }
    }
    # 2. Copy back from backup
    Get-ChildItem $BackupPath -Recurse | ForEach-Object {
        # Complex restore logic omitted for brevity, but essentially copy back
        # Since we mirrored the structure in backup, we can merge copy back to AC Root
    }
    # Simplified restore:
    Copy-Item -Path "$BackupPath\*" -Destination $ACPath -Recurse -Force
    Log-Message "Restored." "Green"
}

# Cleanup
if ($IsArchive) { Remove-Item $TempPath -Recurse -Force }
Remove-Item $BackupPath -Recurse -Force -ErrorAction SilentlyContinue

Read-Host "Press Enter to Exit"
