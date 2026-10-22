$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectRoot

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    throw 'Python was not found on PATH. Install Python 3.11 or newer, then run this script again.'
}

$pythonVersion = & python --version 2>&1
Write-Host "Using $pythonVersion"

if (-not (Test-Path '.venv\Scripts\python.exe')) {
    Write-Host 'Creating virtual environment...'
    & python -m venv .venv
}

Write-Host 'Installing required packages...'
& .venv\Scripts\python.exe -m pip install --upgrade pip
& .venv\Scripts\python.exe -m pip install -r requirements.txt

Write-Host ''
Write-Host 'Setup complete.'
Write-Host 'Train:    .venv\Scripts\python.exe train.py'
Write-Host 'Evaluate: .venv\Scripts\python.exe train.py --evaluate'
Write-Host 'Predict:  .venv\Scripts\python.exe predict.py --source sample-images'
