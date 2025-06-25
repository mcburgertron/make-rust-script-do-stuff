<#
.SYNOPSIS
    Atlassian‑Jira Token Micro‑Service
.DESCRIPTION
    Exposes GET http://*:8080/token
    Returns a new access token, refreshing the refresh/access pair:
        • on every request
        • every 55 minutes in the background
.PARAMETER ClientId
    Atlassian OAuth client ID
.PARAMETER ClientSecret
    Atlassian OAuth client secret
.PARAMETER AuthCode
    One‑time authorization code from the Atlassian consent screen. 
    Needed only the first time; afterwards the stored refresh token is reused.
.PARAMETER Port
    TCP port to listen on (default 8080)
#>
param(
    [Parameter(Mandatory=$true)][string] $ClientId,
    [Parameter(Mandatory=$true)][string] $ClientSecret,
    [string] $AuthCode,
    [int] $Port = 8080
)

# ------------- Logging -----------------------------------------------
$LogFilePath = Join-Path $PSScriptRoot 'boarder.log'
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = 'INFO'
    )
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
    Add-Content -Path $LogFilePath -Value $logEntry
}

# ------------- Configuration persistence ------------------------------------
$TokenStorePath = Join-Path $PSScriptRoot 'jira_refresh.token'

function Save-RefreshToken([string]$token) {
    Set-Content -LiteralPath $TokenStorePath -Value $token -Encoding ASCII
    Write-Log "Refresh token saved to $TokenStorePath" 'DEBUG'
}

function Load-RefreshToken {
    if (Test-Path $TokenStorePath) { Get-Content -LiteralPath $TokenStorePath -Raw }
    else { '' }
}

# ------------- Token routines ----------------------------------------------
$Config = [ordered]@{
    ClientId     = $ClientId
    ClientSecret = $ClientSecret
    RefreshToken = Load-RefreshToken
    RedirectUri  = 'http://localhost:8080'
}

$global:TokenInfo = $null     # will hold current access + refresh + expiry

function Get-RefreshTokenFromAuthCode([string]$code) {
    Write-Log "Requesting refresh token using authorization code" 'INFO'
    $body = @{
        grant_type    = 'authorization_code'
        client_id     = $Config.ClientId
        client_secret = $Config.ClientSecret
        code          = $code
        redirect_uri  = $Config.RedirectUri
    } | ConvertTo-Json
    $resp = Invoke-RestMethod -Method Post -Uri 'https://auth.atlassian.com/oauth/token' `
                              -ContentType 'application/json' -Body $body
    if (-not $resp.refresh_token) { 
        Write-Log 'No refresh token returned from authorization code exchange' 'ERROR'
        throw 'No refresh token returned' 
    }
    $Config.RefreshToken = $resp.refresh_token
    Save-RefreshToken $resp.refresh_token
    Write-Log "Obtained new refresh token from authorization code" 'INFO'
    return $resp
}

function Get-AccessTokenFromRefresh {
    Write-Log "Requesting access token using refresh token" 'INFO'
    $body = @{
        grant_type    = 'refresh_token'
        client_id     = $Config.ClientId
        client_secret = $Config.ClientSecret
        refresh_token = $Config.RefreshToken
    } | ConvertTo-Json
    $resp = Invoke-RestMethod -Method Post -Uri 'https://auth.atlassian.com/oauth/token' `
                              -ContentType 'application/json' -Body $body
    if (-not $resp.refresh_token) { 
        Write-Log 'Refresh failed—no new refresh token delivered' 'ERROR'
        throw 'Refresh failed—no new refresh token delivered' 
    }
    $Config.RefreshToken = $resp.refresh_token
    Save-RefreshToken $resp.refresh_token
    Write-Log "Obtained new access and refresh token from refresh token" 'INFO'
    return $resp
}

function Renew-Tokens {
    try {
        Write-Log "Attempting to renew tokens" 'INFO'
        if ([string]::IsNullOrWhiteSpace($Config.RefreshToken)) {
            if ([string]::IsNullOrWhiteSpace($AuthCode)) {
                Write-Log 'First run needs -AuthCode.' 'ERROR'
                throw 'First run needs -AuthCode.'
            }
            $resp = Get-RefreshTokenFromAuthCode $AuthCode
            $Script:AuthCode = $null   # ensure it is used only once
        } else {
            $resp = Get-AccessTokenFromRefresh
        }
        $global:TokenInfo = [pscustomobject]@{
            AccessToken  = $resp.access_token
            RefreshToken = $resp.refresh_token
            ExpiresAt    = (Get-Date).AddSeconds($resp.expires_in)
        }
        Write-Log "Token renewal successful. Expires at $($global:TokenInfo.ExpiresAt)" 'INFO'
    }
    catch {
        Write-Log "Token renewal failed: $_" 'ERROR'
        Write-Warning "Token renewal failed: $_"
    }
}

# Initial renewal
Write-Log "Performing initial token renewal" 'INFO'
Renew-Tokens
if (-not $TokenInfo) { Write-Log 'Unable to obtain initial tokens.' 'ERROR'; Write-Error 'Unable to obtain initial tokens.'; exit 1 }

# ------------- Background timer -------------------------------------------
$Timer = [System.Timers.Timer]::new(55 * 60 * 1000)   # 55 minutes
$Timer.AutoReset = $true
$Timer.add_Elapsed({ Renew-Tokens })
$Timer.Start()

# ------------- HTTP listener ----------------------------------------------
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://*:$Port/")
$listener.Start()
Write-Log "Token server listening on http://*:$Port/token" 'INFO'
Write-Host "Token server listening on http://*:$Port/token"

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()  # blocks
        $request = $context.Request
        $response = $context.Response

        Write-Log "Received $($request.HttpMethod) request for $($request.Url.AbsolutePath) from $($request.RemoteEndPoint)" 'INFO'

        if ($request.HttpMethod -eq 'GET' -and $request.Url.AbsolutePath -eq '/token') {
            Renew-Tokens          # force immediate fresh pair
            $payload = @{
                access_token = $TokenInfo.AccessToken
                expires_at   = $TokenInfo.ExpiresAt.ToUniversalTime().ToString('o')
            } | ConvertTo-Json -Depth 3

            $buffer = [System.Text.Encoding]::UTF8.GetBytes($payload)
            $response.ContentType = 'application/json'
            $response.ContentLength64 = $buffer.Length
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            Write-Log "Responded with new access token" 'INFO'
        }
        else {
            $response.StatusCode = 404
            Write-Log "Responded with 404 for $($request.Url.AbsolutePath)" 'WARN'
        }
        $response.Close()
    }
}
finally {
    $Timer.Stop()
    $listener.Stop()
    Write-Log "Server stopped" 'INFO'
}

#---------------------- End of File -----------------------------------------
