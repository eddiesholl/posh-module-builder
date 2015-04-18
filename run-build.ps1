
# Check that PsGet is installed
if (!(Get-Command "install-module" -errorAction SilentlyContinue))
{
    Write-Host "Installing PsGet..."
    (new-object Net.WebClient).DownloadString("http://psget.net/GetPsGet.ps1") | iex
}

Write-Host "Installing dependencies..."
install-module psake -update
install-module pester -update

Write-Host "Running the build..."
invoke-psake build-steps.ps1