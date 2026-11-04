#requires -Version 5.1
<#
.SYNOPSIS
    闲鱼自动回复系统 - Windows Docker 部署/更新脚本
.DESCRIPTION
    使用阿里云预构建镜像启动 MySQL、Redis 及四个应用服务。
    首次运行前请确认当前目录存在 .env（本次部署已生成）。
.EXAMPLE
    .\deploy.ps1
.EXAMPLE
    .\deploy.ps1 -SkipPull
#>
[CmdletBinding()]
param(
    [switch]$SkipPull,
    [switch]$NoWait
)

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

$ComposeFile = Join-Path $PSScriptRoot 'docker-compose.deploy.yml'
$EnvFile = Join-Path $PSScriptRoot '.env'
$Compose = @('compose', '-f', $ComposeFile, '--env-file', $EnvFile)

function Invoke-Compose {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    & docker @Compose @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose $($Arguments -join ' ') 执行失败（退出码 $LASTEXITCODE）"
    }
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw '未找到 docker 命令，请先安装并启动 Docker Desktop。'
}
if (-not (Test-Path -LiteralPath $ComposeFile)) {
    throw "缺少配置文件：$ComposeFile"
}
if (-not (Test-Path -LiteralPath $EnvFile)) {
    throw "缺少环境变量文件：$EnvFile"
}
if (-not (& docker info 2>$null)) {
    throw 'Docker 引擎未运行，请先启动 Docker Desktop。'
}

$dirs = @(
    'xianyu_auto_reply\mysql\data',
    'xianyu_auto_reply\redis\data',
    'xianyu_auto_reply\logs\backend_web',
    'xianyu_auto_reply\logs\websocket',
    'xianyu_auto_reply\logs\scheduler',
    'xianyu_auto_reply\static',
    'xianyu_auto_reply\backups',
    'xianyu_auto_reply\browser_data'
)
foreach ($dir in $dirs) {
    New-Item -ItemType Directory -Force -Path (Join-Path $PSScriptRoot $dir) | Out-Null
}

if (-not $SkipPull) {
    Write-Host '[1/2] 拉取镜像...' -ForegroundColor Cyan
    Invoke-Compose -Arguments @('pull')
}

Write-Host '[2/2] 启动服务...' -ForegroundColor Cyan
Invoke-Compose -Arguments @('up', '-d', '--remove-orphans')

if (-not $NoWait) {
    $containers = @(
        'xianyu-mysql',
        'xianyu-redis',
        'xianyu-backend-web',
        'xianyu-websocket',
        'xianyu-scheduler',
        'xianyu-frontend'
    )
    Write-Host '等待容器健康检查通过...' -ForegroundColor Cyan
    for ($i = 1; $i -le 36; $i++) {
        $states = foreach ($name in $containers) {
            $state = & docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' $name 2>$null
            [pscustomobject]@{ Name = $name; State = $state }
        }
        $states | Format-Table -AutoSize
        if (($states | Where-Object { $_.State -notin @('healthy', 'running') }).Count -eq 0) {
            break
        }
        if ($i -lt 36) { Start-Sleep -Seconds 5 }
    }
}

Write-Host ''
Invoke-Compose -Arguments @('ps')
Write-Host ''
Write-Host '部署完成：' -ForegroundColor Green
Write-Host '  前端：       http://localhost:9000'
Write-Host '  API 文档：   http://localhost:8089/docs'
Write-Host '  默认管理员： admin / admin123（登录后请立即修改）'
