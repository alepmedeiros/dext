$baseUrl = "http://localhost:8080"

Write-Host "--- Testing Dext Basic Auth Demo ---" -ForegroundColor Cyan

# 1. Public Endpoint
Write-Host "`n1. Accessing PUBLIC endpoint..." -NoNewline
$resp = Invoke-WebRequest -Uri "$baseUrl/api/publico" -ErrorAction SilentlyContinue
if ($resp.StatusCode -eq 200) {
    Write-Host " [OK] 200" -ForegroundColor Green
} else {
    Write-Host " [FAILED] $($resp.StatusCode)" -ForegroundColor Red
}

# 2. Private Endpoint without auth
Write-Host "2. Accessing PRIVATE endpoint WITHOUT credentials..." -NoNewline
try {
    $resp = Invoke-WebRequest -Uri "$baseUrl/api/privado" -ErrorAction Stop
    Write-Host " [FAILED] Should have been 401" -ForegroundColor Red
} catch {
    if ($_.Exception.Response.StatusCode -eq 401) {
        Write-Host " [OK] 401 Unauthorized (Expected)" -ForegroundColor Green
    } else {
        Write-Host " [FAILED] $($_.Exception.Response.StatusCode)" -ForegroundColor Red
    }
}

# 3. Private Endpoint with correct auth
Write-Host "3. Accessing PRIVATE endpoint WITH VALID credentials..." -NoNewline
$pair = "admin:secret"
$bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
$base64 = [System.Convert]::ToBase64String($bytes)
$headers = @{ "Authorization" = "Basic $base64" }

$resp = Invoke-WebRequest -Uri "$baseUrl/api/privado" -Headers $headers -ErrorAction SilentlyContinue
if ($resp.StatusCode -eq 200) {
    Write-Host " [OK] 200" -ForegroundColor Green
    Write-Host "   Response: $($resp.Content)"
} else {
    Write-Host " [FAILED] $($resp.StatusCode)" -ForegroundColor Red
}

# 4. Private Endpoint with wrong auth
Write-Host "4. Accessing PRIVATE endpoint WITH INVALID credentials..." -NoNewline
$pair = "admin:wrong"
$bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
$base64 = [System.Convert]::ToBase64String($bytes)
$headers = @{ "Authorization" = "Basic $base64" }

try {
    $resp = Invoke-WebRequest -Uri "$baseUrl/api/privado" -Headers $headers -ErrorAction Stop
    Write-Host " [FAILED] Should have been 401" -ForegroundColor Red
} catch {
    if ($_.Exception.Response.StatusCode -eq 401) {
        Write-Host " [OK] 401 Unauthorized (Expected)" -ForegroundColor Green
    } else {
        Write-Host " [FAILED] $($_.Exception.Response.StatusCode)" -ForegroundColor Red
    }
}

Write-Host "`n--- Tests Finished ---" -ForegroundColor Cyan
