param(
  [string]$MarketplaceSource = "Divyansh-0909/codex-you-should-know"
)

$ErrorActionPreference = "Stop"

function Require-Command([string]$Name, [string]$Hint) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "$Name is required. $Hint"
  }
}

function Invoke-CodexJson([string[]]$Arguments) {
  $output = & codex @Arguments 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "codex $($Arguments -join ' ') failed:`n$($output -join [Environment]::NewLine)"
  }
  return ($output -join [Environment]::NewLine) | ConvertFrom-Json
}

function Remove-CompatibilityBlock([string]$Text) {
  $pattern = '(?ms)\r?\n?# BEGIN you-should-know compatibility hooks.*?# END you-should-know compatibility hooks\r?\n?'
  return [regex]::Replace($Text, $pattern, [Environment]::NewLine).TrimEnd()
}

Require-Command "codex" "Install or update the OpenAI Codex CLI first."
Require-Command "node" "Install Node.js 18 or newer first."

$nodeVersion = (& node -p "Number(process.versions.node.split('.')[0])").Trim()
if ([int]$nodeVersion -lt 18) {
  throw "Node.js 18+ is required. Found Node.js $(& node --version)."
}

Write-Host "Adding You Should Know marketplace..."
$marketplace = Invoke-CodexJson @("plugin", "marketplace", "add", $MarketplaceSource, "--json")

Write-Host "Installing You Should Know..."
$install = Invoke-CodexJson @("plugin", "add", "you-should-know@you-should-know", "--json")
$pluginRoot = [string]$install.installedPath
if (-not $pluginRoot) {
  throw "Codex installed the plugin but did not return installedPath."
}

$featureOutput = (& codex features list 2>&1) -join [Environment]::NewLine
$nativePluginHooks = $featureOutput -match '(?m)^plugin_hooks\s+\S+\s+true\s*$'

$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }
$configPath = Join-Path $codexHome "config.toml"
New-Item -ItemType Directory -Force -Path $codexHome | Out-Null

if ($nativePluginHooks) {
  Write-Host "This Codex build supports plugin hooks natively; no compatibility config is needed."
} else {
  Write-Host "Registering compatibility hooks for this Codex build..."
  $current = if (Test-Path $configPath) { Get-Content -Raw $configPath } else { "" }
  $current = Remove-CompatibilityBlock $current

  $root = $pluginRoot.Replace('\', '/')
  $post = "node `"$root/hooks/post-tool-use.mjs`""
  $stop = "node `"$root/hooks/stop.mjs`""

  $block = @"
# BEGIN you-should-know compatibility hooks
[[hooks.PostToolUse]]

[[hooks.PostToolUse.hooks]]
type = "command"
command = '$post'
command_windows = '$post'
timeout = 5

[[hooks.Stop]]

[[hooks.Stop.hooks]]
type = "command"
command = '$stop'
command_windows = '$stop'
timeout = 35
statusMessage = "Checking what you should know"
# END you-should-know compatibility hooks
"@

  $next = if ($current) { "$current`r`n`r`n$block`r`n" } else { "$block`r`n" }
  Set-Content -Path $configPath -Value $next -Encoding UTF8
}

Write-Host ""
Write-Host "You Should Know is installed."
Write-Host "Restart Codex. If Codex asks to review new hooks, inspect them and choose 'Trust all and continue' to activate them."
