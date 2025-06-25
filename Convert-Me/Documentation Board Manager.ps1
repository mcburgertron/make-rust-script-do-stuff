# --------------------------------------------------------------------
# Atlassian Jira Token Management Script
# This script handles OAuth token management for Atlassian Jira API access
# --------------------------------------------------------------------

# Configuration
if ($IsWindows) {
    $ClientId = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR(
            (Get-Secret -Name degirum_jira_client_id)
        )
    )
    $ClientSecret = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR(
            (Get-Secret -Name degirum_jira_client_secret)
        )
    )
} else {
    $ClientId = [System.Net.NetworkCredential]::new("", (Get-Secret -Name degirum_jira_client_id)).Password
    $ClientSecret = [System.Net.NetworkCredential]::new("", (Get-Secret -Name degirum_jira_client_secret)).Password
}

$Config = @{
    ClientId     = $ClientId
    ClientSecret = $ClientSecret
    RefreshToken = ""
    RedirectUri  = "http://localhost:8080"
}

# Authorization URL for initial setup
$AuthUrl = "https://auth.atlassian.com/authorize?audience=api.atlassian.com&client_id=$($Config.ClientId)&scope=offline_access%20read%3Ajira-user%20manage%3Ajira-configuration%20manage%3Ajira-project%20manage%3Ajira-webhook%20write%3Ajira-work%20read%3Ajira-work&redirect_uri=$($Config.RedirectUri)&state=`${YOUR_USER_BOUND_VALUE}&response_type=code&prompt=consent"

# --------------------------------------------------------------------
# Token Management Functions
# --------------------------------------------------------------------

function Get-RefreshTokenFromAuthCode {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$AuthCode
    )

    $body = @{
        grant_type    = 'authorization_code'
        client_id     = $Config.ClientId
        client_secret = $Config.ClientSecret
        code          = $AuthCode
        redirect_uri  = $Config.RedirectUri
    } | ConvertTo-Json

    try {
        $resp = Invoke-RestMethod -Method Post `
            -Uri 'https://auth.atlassian.com/oauth/token' `
            -ContentType 'application/json' `
            -Body $body

        if ($resp.refresh_token) {
            $script:Config.RefreshToken = $resp.refresh_token
            $issuedAt = Get-Date
            $expiresAt = $issuedAt.AddSeconds($resp.expires_in)
            Write-Host ("Successfully obtained refresh token")
            Write-Host ("Access token expires at: {0:u} (in {1} seconds)" -f $expiresAt, $resp.expires_in)
            return @{
                AccessToken  = $resp.access_token
                RefreshToken = $resp.refresh_token
                ExpiresIn    = $resp.expires_in
                ExpiresAt    = $expiresAt
            }
        }
        else {
            Write-Error "No refresh token received in response"
            return $null
        }
    }
    catch {
        Write-Error "Failed to exchange authorization code for refresh token: $_"
        return $null
    }
}


function Get-AccessTokenFromRefresh {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$ClientId,
        [Parameter(Mandatory)][string]$ClientSecret,
        [Parameter(Mandatory)][string]$RefreshToken
    )

    $body = @{
        grant_type    = 'refresh_token'
        client_id     = $ClientId
        client_secret = $ClientSecret
        refresh_token = $RefreshToken
    } | ConvertTo-Json

    try {
        $resp = Invoke-RestMethod -Method Post `
            -Uri 'https://auth.atlassian.com/oauth/token' `
            -ContentType 'application/json' `
            -Body $body

        # Atlassian always issues a new refresh token with each access token refresh
        if ($resp.refresh_token) {
            $script:Config.RefreshToken = $resp.refresh_token
            Write-Host "New refresh token received and stored"
        }
        else {
            Write-Error "No refresh token received in response - this is unexpected"
            throw "Token refresh failed: No refresh token received"
        }

        $issuedAt = Get-Date
        $expiresAt = $issuedAt.AddSeconds($resp.expires_in)
        Write-Host ("Access token expires at: {0:u} (in {1} seconds)" -f $expiresAt, $resp.expires_in)

        return [PSCustomObject]@{
            AccessToken  = $resp.access_token
            RefreshToken = $resp.refresh_token
            ExpiresIn    = $resp.expires_in
            ExpiresAt    = $expiresAt
            TokenType    = $resp.token_type
            Scope        = $resp.scope
        }
    }
    catch {
        Write-Error "Failed to refresh access token: $_"
        throw
    }
}


function Get-CloudId {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$AccessToken
    )

    $Headers = @{
        Authorization = "Bearer $AccessToken"
    }

    try {
        $Resources = Invoke-RestMethod `
            -Method Get `
            -Uri "https://api.atlassian.com/oauth/token/accessible-resources" `
            -Headers $Headers

        return $Resources[0].id
    }
    catch {
        Write-Error "Failed to get Cloud ID: $_"
        throw
    }
}

function Initialize-JiraAccess {
    [CmdletBinding()]
    param(
        [string]$AuthCode
    )

    if ([string]::IsNullOrEmpty($Config.RefreshToken)) {
        if ([string]::IsNullOrEmpty($AuthCode)) {
            Write-Host "No refresh token found. Please follow these steps:"
            Write-Host "1. Open this URL in your browser: $AuthUrl"
            Write-Host "2. Authorize the application"
            Write-Host "3. Copy the authorization code from the redirect URL (it's the 'code' parameter)"
            Write-Host "4. Run Initialize-JiraAccess -AuthCode 'your_code_here'"
            return $false
        }
        else {
            $tokenInfo = Get-RefreshTokenFromAuthCode -AuthCode $AuthCode
            if (-not $tokenInfo) {
                return $false
            }
            $accessToken = $tokenInfo.AccessToken
        }
    }
    else {
        try {
            $tokenInfo = Get-AccessTokenFromRefresh -ClientId $Config.ClientId `
                -ClientSecret $Config.ClientSecret `
                -RefreshToken $Config.RefreshToken
            $accessToken = $tokenInfo.AccessToken
        }
        catch {
            Write-Error "Failed to refresh access token. You may need to reauthorize the application."
            return $false
        }
    }

    try {
        $cloudId = Get-CloudId -AccessToken $accessToken

        return @{
            AccessToken  = $accessToken
            CloudId      = $cloudId
            RefreshToken = $Config.RefreshToken  # Include the latest refresh token in the return value
        }
    }
    catch {
        Write-Error "Failed to initialize Jira access: $_"
        return $false
    }
}

# Example usage:
# First time setup:
# 1. Run Initialize-JiraAccess to get the authorization URL
# 2. After getting the code from the URL, run:
# $jiraAccess = Initialize-JiraAccess -AuthCode "your_code_here"
#
# Subsequent uses:
# $jiraAccess = Initialize-JiraAccess
# if ($jiraAccess) {
#     Write-Host "Successfully connected to Jira Cloud ID: $($jiraAccess.CloudId)"
#     # Store $jiraAccess.RefreshToken for future use if needed
# }


# --------------------------------------------------------------------
# End of Script
# -------------------------------------------------------------------- 

