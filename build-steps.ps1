$ErrorActionPreference = 'stop'

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

Properties {
    if ($configFile -eq $null) { $configFile = ".\config.ps1" }

    if (!(Test-Path $configFile)) { Write-Error "Could not find mandatory config file $configFile" }

    . $configFile

    if ($modulesToPack -eq $null) { Write-Error "Variable modulesToPack not set. Please include this in $configFile" }

    $absoluteModulePaths = $modulesToPack | ForEach-Object {
        if ([System.IO.Path]::IsPathRooted($_))
        {
            return $_
        }
        else {
            return Join-Path $scriptPath $_
        }
    }

    if (!$packagesDir) { $packagesDir = Join-Path $scriptPath "packages" }

    $installScript = Join-Path $packagesDir "install-modules.ps1"

}

Task default -Depends Full


$rootBuildFolder = Join-Path $scriptPath 'build'

Write-Host "Using ScriptPath $scriptPath"
Write-Host "Using PackagesDir $packagesDir"
Write-Host "Using RootBuildFolder $rootBuildFolder"

Task Full -Depends Pack

Task Pack -Depends Clean,Test,Build {

    New-Item -Type Directory $packagesDir | Out-Null

    ls -Directory $rootBuildFolder | ForEach-Object {
        Pack-Module $_.FullName $packagesDir
    }

    # Generate a script that can be used to install all generated modules
    ls $packagesDir -Filter '*.zip' | ForEach-Object {
        $content = "Install-Module -ModulePath `"$($_.FullName)`" -Update"
        Add-Content $installScript $content
    }

}

Task Clean {
    if (Test-Path $packagesDir) {
        Remove-Item $packagesDir -Recurse
    }

    if (Test-Path $rootBuildFolder) {
        Remove-Item $rootBuildFolder -Recurse
    }
}

Task Test {

    $absoluteModulePaths | ForEach-Object {
        Test-Module $_
    }
}

Task Build {

    if (!(Test-Path $rootBuildFolder)) { New-Item -Type directory $rootBuildFolder | Out-Null }

    $absoluteModulePaths | ForEach-Object {
        Build-Module $_
    }
}

function Build-Module {
    param(
        [Parameter(Mandatory = $true)]
        [string]$moduleFolder
    )

    $moduleName = Split-Path $moduleFolder -Leaf
    $outputFolder = Join-Path $rootBuildFolder $moduleName

    Write-Host "Building module from $moduleFolder into $outputFolder"

    if (!(Test-Path $outputFolder)) { New-Item -Type directory $outputFolder | Out-Null }

    $psdPath = Join-Path $moduleFolder "$moduleName.psd1"
    $psmPath = Join-Path $moduleFolder "$moduleName.psm1"

    if (Test-Path $psmPath)
    {
        Copy-Item $psmPath $outputFolder
    }
    else {
        Write-Error "Could not find module script at $psmPath"
    }

    $manifestContent = Test-ModuleManifest $psdPath

    if (!$manifestContent) { Write-Error "Could not parse module manifest $psdPath" }

    $scriptsToProcess = $manifestContent.NestedModules

    if ($scriptsToProcess -and $scriptsToProcess.Length -gt 0)
    {
        Write-Host "Updating NestedModules in $psdPath"

        $updatedScriptPaths = @()
        $scriptsToProcess | ForEach-Object {
            $scriptPath = $_.Path
            if (Test-Path $scriptPath)
            {
                Write-Host "Copying referenced script $scriptPath to $outputFolder"
                Copy-Item $scriptPath $outputFolder

                $newRelativeScriptPath = Split-Path -Leaf $scriptPath
                $updatedScriptPaths += $newRelativeScriptPath
                Write-Host "Using new relative path for script $newRelativeScriptPath"
            }
            else {
                Write-Error "Could not find referenced script file $scriptPath"
            }
        }

        $updatedPsdPath = Join-Path $outputFolder "$moduleName.psd1"

        New-ModuleManifest -Path $updatedPsdPath -ScriptsToProcess $manifestContent.Scripts -NestedModules $updatedScriptPaths -Guid $manifestContent.Guid -Author $manifestContent.Author -CompanyName $manifestContent.CompanyName -Copyright $manifestContent.Copyright -RootModule $manifestContent.RootModule -ModuleVersion $manifestContent.Version -Description $manifestContent.Description -ProcessorArchitecture $manifestContent.ProcessorArchitecture -PowerShellVersion $manifestContent.PowerShellVersion -ClrVersion $manifestContent.ClrVersion -DotNetFrameworkVersion $manifestContent.DotNetFrameworkVersion -PowerShellHostName $manifestContent.PowerShellHostName -PowerShellHostVersion $manifestContent.PowerShellVersion -RequiredModules $manifestContent.RequiredModules -TypesToProcess $manifestContent.TypesToProcess -FormatsToProcess $manifestContent.FormatsToProcess -RequiredAssemblies $manifestContent.RequiredAssemblies -FileList $manifestContent.FileList -ModuleList $manifestContent.ModuleList -FunctionsToExport $manifestContent.FunctionsToExport -AliasesToExport $manifestContent.AliasesToExport -VariablesToExport $manifestContent.VariablesToExport -CmdletsToExport $manifestContent.CmdletsToExport -PrivateData $manifestContent.PrivateData -HelpInfoUri $manifestContent.HelpInfoUri
    }
    elseif (Test-Path $psdPath) {
        Write-Host "Using original manifest file $psdPath"
        Copy-Item $psdPath $outputFolder
    }
    else {
        Write-Error "Could not find module manifest at $psdPath"
    }

}

function Pack-Module {
    param(
        [Parameter(Mandatory = $true)]
        [string]$sourceFolder,
        [Parameter(Mandatory = $true)]
        [string]$destFolder
    )

    $moduleName = Split-Path $sourceFolder -Leaf
    $packagePath = Join-Path $destFolder "$moduleName.zip"

    Write-Host "Packing module $moduleName from $sourceFolder to $packagePath"

    ls "$sourceFolder\*" | out-zip -Path $packagePath

    Write-Host "Created module package $packagePath"
}

function Test-Module {
    param(
        [Parameter(Mandatory = $true)]
        [string]$sourceFolder
    )

    Write-Host "Running tests in $sourceFolder"

    Write-Host "TODO invoke Pester for tests"
}

function out-zip {
    param([string]$path)

    if (-not $path.EndsWith('.zip')) { $path += '.zip' }

    $7z = Join-Path $scriptPath "bin\7z.exe"

    $args = @( "a",$path) + $input
    Write-Host "Packing zip $path with cmd line $args"

    & $7z $args

    if ($lastexitcode -ne 0)
    {
        Write-Error "7zip failed with exit code $lastexitcode"
    }
}
