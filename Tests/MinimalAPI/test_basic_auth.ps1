# Basic Auth Enforcement Test Script
$baseUrl = "http://localhost:8081"

Write-Host "[TEST] Dext Basic Auth Enforcement" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan

function Test-Auth {
    param($Method, $Url, $User = $null, $Pass = $null, $ExpectedStatus = 200)
    
    Write-Host "Testing $Method $Url (Auth: $User:$Pass)..." -NoNewline -ForegroundColor Yellow
    
    $headers = @{}
    if ($User) {
        $pair = "$User:$Pass"
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
        $base64 = [System.Convert]::ToBase64String($bytes)
        $headers["Authorization"] = "Basic $base64"
    }

    try {
        $resp = Invoke-WebRequest -Uri "$baseUrl$Url" -Method $Method -Headers $headers -ErrorAction Stop
        if ($resp.StatusCode -eq $ExpectedStatus) {
            Write-Host " [OK] $($resp.StatusCode)" -ForegroundColor Green
        } else {
            Write-Host " [FAILED] Status: $($resp.StatusCode), Expected: $ExpectedStatus" -ForegroundColor Red
        }
    }
    catch {
        if ($_.Exception.Response.StatusCode.value__ -eq $ExpectedStatus) {
            Write-Host " [OK] $($_.Exception.Response.StatusCode.value__) (Expected)" -ForegroundColor Green
        } else {
            Write-Host " [FAILED] Status: $($_.Exception.Response.StatusCode.value__), Expected: $ExpectedStatus" -ForegroundColor Red
        }
    }
}

Write-Host "Waiting for test server to start..."
Start-Sleep -Seconds 2

# 1. Public endpoint
Test-Auth "GET" "/public" -ExpectedStatus 200

# 2. Protected endpoint without auth
Test-Auth "GET" "/protected" -ExpectedStatus 401

# 3. Protected endpoint with CORRECT auth
Test-Auth "GET" "/protected" -User "testuser" -Pass "testpass" -ExpectedStatus 200

# 4. Protected endpoint with WRONG auth
Test-Auth "GET" "/protected" -User "testuser" -Pass "wrong" -ExpectedStatus 401

Write-Host "`n[DONE] Basic Auth Enforcement verified!" -ForegroundColor Green
