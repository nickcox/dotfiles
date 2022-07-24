Set-StrictMode -Version Latest
Write-Host -NoNewline "`e[2 q" # disable cursor blink
$Private:LOCALAPPDATA = [System.Environment]::GetFolderPath(
  [System.Environment+SpecialFolder]::LocalApplicationData)

# psreadline
Set-PSReadLineOption -ShowToolTips
Set-PSReadLineOption -EditMode Windows
Set-PSReadLineOption -HistoryNoDuplicates:$True
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineOption -CompletionQueryItems 1024
Set-PSReadLineOption -Colors @{ Selection = $PSStyle.Reverse }
Set-PSReadLineOption -PredictionSource History

# cd-extras
if (Get-Module -ListAvailable cd-extras) {
  Import-Module $HOME\scripts\cd-extras\cd-extras\cd-extras.psd1
  setocd @{
    ColorCompletion  = $true
    CDABLE_VARS      = $true
    RECENT_DIRS_FILE = "$LOCALAPPDATA/.recent"
    PathCompletions  = 'Invoke-VSCode'
  }

  function promptOnIdle() {
    [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
  }

  @{
    'Alt+['         = { if (cd- -PassThru) { promptOnIdle } }
    'Alt+]'         = { if (cd+ -PassThru) { promptOnIdle } }
    'Alt+^'         = { if (up -PassThru) { promptOnIdle } }
    'Alt+Backspace' = { if (cdb -PassThru) { promptOnIdle } }
  }.GetEnumerator() | % { Set-PSReadLineKeyHandler $_.Name $_.Value }

  function Format-ColorizedFilename([IO.FileSystemInfo] $item) {
    function fmt([string] $colour) { $colour + $item.Name + $PSStyle.Reset }
    function isExe() { $IsWindows ? $item.Extension -in $cde.executableEx : $item.UnixMode -like '*x' }

    if ($item.LinkTarget) { fmt $PSStyle.FileInfo.SymbolicLink }
    elseif ($item -is [IO.DirectoryInfo]) { fmt $PSStyle.FileInfo.Directory }
    elseif (isExe $item) { fmt $PSStyle.FileInfo.Executable }
    elseif ($PSStyle.FileInfo.Extension.ContainsKey($item.Extension)) { fmt $PSStyle.FileInfo.Extension[$item.Extension] }
    else { $item.Name }
  }
}

# starship
$global:LASTEXITCODE = 0 # avoid strict mode error
$ENV:STARSHIP_CONFIG = "$PSScriptRoot\starship-config.toml"
Set-PSReadLineOption -ExtraPromptLineCount 2 # per Pure preset
& $PSScriptRoot/starship.ps1

# pretty colours
$PSStyle.Formatting.TableHeader = $PSStyle.Italic + $PSStyle.Bold
$PSStyle.FileInfo.Extension.Clear()

Function Use-LSColors {
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string]$LSColors
  )

  $LSColors -Split ":" | % {
    $type, $colour = $_ -Split "="
    $colour = ($colour -replace '^0;', '').Trim()
    if ($type -eq 'di') {
      $PSStyle.FileInfo.Directory = "`e[${colour}m"
    }
    elseif ($type -eq 'ln') {
      $PSStyle.FileInfo.SymbolicLink = "`e[${colour}m"
    }
    elseif ($type -eq 'ex') {
      $PSStyle.FileInfo.Executable = "`e[${colour}m"
    }
    elseif ($type -like '`*.*') {
      $PSStyle.FileInfo.Extension.Add($type.Substring(1), "`e[${colour}m")
    }
  }
}

Use-LSColors (gc $PSScriptRoot/snazzy.dircolors -raw)
$PSStyle.FileInfo.Directory += $PSStyle.Italic

# PowerShell parameter completion shim for the dotnet CLI
if (Get-Command dotnet) {
  Register-ArgumentCompleter -Native -CommandName @('dotnet', 'dn') -ScriptBlock {
    param($commandName, $wordToComplete, $cursorPosition)
    dotnet complete --position $cursorPosition "$wordToComplete" | ForEach-Object {
      [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
  }
}

# lazy load posh-git
Register-ArgumentCompleter -Native -CommandName 'git' -ScriptBlock {
  Expand-GitCommand ($args[1] -replace '^git\W*', '')
}

#aliases and wrappers
${~code} = '~/code'
function Invoke-VSCode($path = $PWD) { &code (Resolve-Path $path) }
Set-Alias o invoke-item
Set-Alias s select
Set-Alias halp help
Set-Alias ll ls
Set-Alias co Invoke-VSCode
Set-Alias dn dotnet
Set-Alias z Set-RecentLocation

# env vars
# Setup path for nvm linked version at the front to make sure it's used
$Env:Path = "C:\Users\ncox\nvm\nodejs\bin;$Env:Path"

$env:GIT_EDITOR = 'nano'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = 1
$env:POWERSHELL_TELEMETRY_OPTOUT = 1
