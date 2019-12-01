if ($env:STRESS_TIMEOUT) { 
    $timeout = [int]$env:STRESS_TIMEOUT
} 
else {
    $timeout = 60
}

Write-Output "Timeout set to $timeout"

while ($true) {
    $epochTime=[Math]::Floor([decimal](Get-Date(Get-Date).ToUniversalTime()-uformat "%s"))
    $doubleTime = $timeout * 2
    $modulo = $epochTime % $doubleTime
    if ($modulo -gt $timeout) {
        Write-Output "Generating stress, time $modulo to $doubleTime"
        $result = 1; foreach ($number in 1..1000000) {$result = $result * $number};
    }
    else {
        Write-Output "Idle"
        Start-Sleep -s 2
    }
}