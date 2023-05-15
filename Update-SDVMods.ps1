function Test-Dependencies {
    $DependencyList = @("7Zip4Powershell")
    ForEach ($Dependency in $DependencyList) {
        if (!(Get-Module -ListAvailable -Name $Dependency)) {
            Write-Host "$Dependency Module not found - exiting script"
        Exit
        }
    }
}

function Get-NexusModArchive {

    [CmdletBinding()]
    param ( 
        [Parameter(Mandatory=$true,HelpMessage="API Key from Nexus account - go to https://www.nexusmods.com/users/myaccount?tab=api and generate a Personal API Key at the bottom of the page.  It should be a long string that ends with '==' ")]
        [string]$ApiKey,
        [Parameter(Mandatory=$true,HelpMessage="Known as `"mod_id`" in Nexus API.  See https://app.swaggerhub.com/apis-docs/NexusMods/nexus-mods_public_api_params_in_form_data/1.0#/Mod%20Files/get_v1_games_game_domain_mods_mod_id_files_id_download_link.json")]
        [Int32]$ModID,
        [Parameter(Mandatory=$true,HelpMessage="Possible mirror values: `"Nexus CDN`",`"Paris`",`"Amsterdam`",`"Prague`",`"Chicago`",`"Los Angeles`",`"Miami`",`"Singapore`"")]
        [string]$Mirror,
        [Parameter(Mandatory=$True,HelpMessage="Folder to download archive to")]
        [string]$FilePath
    )

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $keyHeader = @{
        apikey = $ApiKey
    }
    $Game = "stardewvalley"
    Write-Verbose "BEGIN Get-NexusModArchive verbose output"
    Write-Verbose "ModID: $ModID"
    Write-Verbose "Mirror: $Mirror"
    Write-Verbose "FilePath: $FilePath"

    Write-Verbose "Creating $FilePath directory if it does not exist"
    $FilePath = New-Item -ItemType Directory -Path $FilePath -Force

    # Retrieve a file_id from a mod_id by looking for files in 'MAIN' category - if more than one exists in 'MAIN' the user is prompted
    # URI builder - see https://app.swaggerhub.com/apis-docs/NexusMods/nexus-mods_public_api_params_in_form_data/1.0#/Mod%20Files/get_v1_games_game_domain_mods_mod_id_files.json
    $ModListUri = "https://api.nexusmods.com/v1/games/$Game/mods/$ModID/files.json"
    Write-Verbose "ModListUri: $ModListUri"
    # Invoke rest method for json response containing file list for specificed mod_id
    $ModListResponse = Invoke-RestMethod -Uri $ModListUri -ContentType application/json -Headers $keyHeader
    # filter out mods containing these element(s) such as xnb-based mods which are out of the scope of this script
    $ModNameMatchBlacklist = @("xnb")
    Write-Verbose "ModNameMatchBlacklist: $ModNameMatchBlacklist"
    # Select file in 'MAIN' category and filter out items in ModNameMatchBlackList
    $ModFileSelection = $ModListResponse.files | Where-Object {$_.category_name -eq 'MAIN' -and $_.name -notmatch $ModNameMatchBlacklist}
    # Send number of results to a variable
    $NumOfResults = $ModFileSelection.count
    Write-Verbose "NumOfResults: $NumOfResults"
    # prompt user if multiple files found in 'MAIN'
    if ($NumofResults -gt 1) {
        Write-Verbose "MULTIPLE FILES MATCHED - $NumofResults"
        # Set ModFileSelection to user selection
        $ModFileSelection = $ModFileSelection | Out-GridView -PassThru -Title "Multiple mod files detected, please select manually."
    }
    # Send name of mod to variable (only used for verbose output for now)
    $ModFileName = $ModFileSelection.file_name
    Write-Verbose "ModFileSelection: $ModFileName"
    # Send file_id of selected mod to variable
    $FileID = $ModFileSelection.file_id
    Write-Verbose "FileID: $FileID"

    $DownloadUri = "https://api.nexusmods.com/v1/games/$Game/mods/$ModID/files/$FileID/download_link.json"
    Write-Verbose "DownloadUri: $DownloadUri"
    $DownloadResponse = Invoke-RestMethod -Uri $DownloadUri -ContentType application/json -Headers $keyHeader
    #Write-Verbose "DownloadResponse: $DownloadResponse"
    $DownloadLink = $DownloadResponse | Where-Object { $_.short_name -eq $Mirror} | Select-Object -ExpandProperty URI
    Write-Verbose "DownloadLink: $DownloadLink "
    $DownloadFileName = $(Select-String -InputObject $DownloadLink -CaseSensitive -Pattern "[^\/\\&\?]+\.\w{2,4}(?=([\?&].*$|$))").matches.groups[0].value
    Write-Verbose "DownloadFileName: $DownloadFileName"
    Invoke-WebRequest -Uri $DownloadLink -OutFile $FilePath\$DownloadFileName
    Write-Verbose "DOWNLOADED $DownloadFileName to $FilePath"
}

function Expand-NexusModArchive {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True,HelpMessage="Folder")]
        [string]$FilePath,
        [Parameter(Mandatory=$False,HelpMessage="Set to True to delete downloaded archives after extracting")]
        [switch]$Cleanup
    )
    $ArchiveExtensions = @('.zip','.7z','.rar')
    $Archives = Get-ChildItem -Path $FilePath | Where-Object {$_.Extension -in $ArchiveExtensions}
    Write-Verbose "ARCHIVES TO EXPAND: $Archives"
    $ModDir = New-Item -ItemType Directory -Path "$FilePath\Mods" -Force
    foreach ($Archive in $Archives) {
        Write-Verbose "EXPANDING: $Archive to $ModDir"
        Expand-7Zip -ArchiveFileName $Archive -TargetPath $ModDir 
        if ($Cleanup) {
            Write-Verbose "CLEANUP: Deleting $Archive"
            Remove-Item $Archive -Force 
        }
    } 
}

function Update-ModFolders {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True,HelpMessage="Path of downloaded Mods folder")]
        [string]$FilePath,
        [Parameter(Mandatory=$True,HelpMessage="Path of mods folder in Stardew Valled game files")]
        [string]$ModsFolder
    )
    # Delete old mod folder if we have a new one
    $DownloadedModsNameList = $(Get-ChildItem $FilePath).Name
    Write-Verbose "Deleting old mod folders"
    Get-ChildItem $ModsFolder | Where-Object {$DownloadedModsNameList -eq $_.Name} | Remove-Item -Recurse -Force

    # Copy new mod folders to game's Mod path
    $DownloadedMods = "$FilePath\*"
    Write-Verbose "Copying new mod folders"
    Copy-Item -Path $DownloadedMods -Destination $ModsFolder -Recurse -Force

    
}

# Script block
# Set variables
$ApiKey = Get-Content $PSScriptRoot\api-key.txt
$WorkingPath = "$PSScriptRoot\working"
$ModList = Import-Csv -Path $PSScriptRoot\modlist.csv
$ModsFolder = "E:\steam\steamapps\common\Stardew Valley\Mods"
$DownloadedMods = "$WorkingPath\mods"

# Test for dependencies and exit if any aren't found
Test-Dependencies

# Enumerate each mod entry from CSV file to download them
foreach ($row in $ModList) {
    Get-NexusModArchive -ApiKey $ApiKey -ModID $row.ModID -Mirror Chicago -FilePath $WorkingPath -Verbose 
}

# Expand archives into mod folder
Expand-NexusModArchive -FilePath $WorkingPath -Cleanup -Verbose


Update-ModFolders -FilePath $DownloadedMods -ModsFolder $ModsFolder -Verbose