if ((Test-Path Env:REDIS_MASTER_SERVICE_HOST) -and (Test-Path Env:REDIS_MASTER_SERVICE_PORT)) {
    c:/redis/redis-server.exe --slaveof $env:REDIS_MASTER_SERVICE_HOST $env:REDIS_MASTER_SERVICE_PORT
}