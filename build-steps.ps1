$ErrorActionPreference = 'stop'

properties {
  if ($configFile -eq $null) { $configFile = ".\config.ps1" }

  if (!(test-path $configFile)) { Write-Error "Could not find mandatory config file $configFile" }

  . $configFile

  if ($modulesToPack -eq $null) { Write-Error "Variable modulesToPack not set. Please include this in $configFile" }
}

Task default -Depends Full

$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition

$packagesDir = join-path $scriptPath "packages"
$installScript = join-path $packagesDir "install-modules.ps1"

$rootBuildFolder = join-path $scriptPath 'build'

write-host "Using ScriptPath $scriptPath"
write-host "Using PackagesDir $packagesDir"
write-host "Using RootBuildFolder $rootBuildFolder"

Task Full -Depends Pack

Task Pack -Depends Clean, Test, Build {
   
   new-item -type Directory $packagesDir | out-null

   ls -Directory $rootBuildFolder | foreach {
        Pack-Module $_.FullName $packagesDir
   }

   # Generate a script that can be used to install all generated modules
   ls $packagesDir -Filter '*.zip' | foreach {
    $content = "Install-Module -ModulePath `"$($_.FullName)`" -Update"
    Add-Content $installScript $content
  }

}

Task Clean {
    if (test-path $packagesDir) {
        remove-item $packagesDir -recurse
    }

    if (test-path $rootBuildFolder) {
        remove-item $rootBuildFolder -recurse
    }
}

Task Test {
   
    $modulesToPack | foreach {
        Test-Module (join-path $scriptPath $_)
   }
 }

 Task Build {

    if (!(test-path $rootBuildFolder)) { new-item -type directory $rootBuildFolder | out-null }

    $modulesToPack | foreach {
        Build-Module $scriptPath $_
   }
 }

function Build-Module {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$rootFolder,
        [Parameter(Mandatory=$true)]
        [string]$moduleName
    )

    $moduleFolder = join-path $rootFolder $moduleName
    $outputFolder = join-path $rootBuildFolder $moduleName

    Write-Host "Building module from $moduleFolder into $outputFolder"

    if (!(test-path $outputFolder)) { new-item -type directory $outputFolder | out-null }

    $psdPath = join-path $moduleFolder "$moduleName.psd1"
    $psmPath = join-path $moduleFolder "$moduleName.psm1"

    if (test-path $psmPath)
    {
      copy-item $psmPath $outputFolder
    }
    else {
        write-error "Could not find module script at $psmPath"
    }

    $manifestContent = test-modulemanifest $psdPath

    if (!$manifestContent) { write-error "Could not parse module manifest $psdPath" }

    $scriptsToProcess = $manifestContent.NestedModules

    if ($scriptsToProcess -and $scriptsToProcess.Length -gt 0)
    {
      write-host "Updating NestedModules in $psdPath"

      $updatedScriptPaths = @()
      $scriptsToProcess | foreach {
          $scriptPath = $_.Path
          if (test-path $scriptPath)
          {
            write-host "Copying referenced script $scriptPath to $outputFolder"
            copy-item $scriptPath $outputFolder

            $newRelativeScriptPath = split-path -leaf $scriptPath
            $updatedScriptPaths += $newRelativeScriptPath
            Write-Host "Using new relative path for script $newRelativeScriptPath"
          }
          else {
              write-error "Could not find referenced script file $scriptPath"
          }
      }

     $updatedPsdPath = join-path $outputFolder "$moduleName.psd1"

      New-ModuleManifest -Path $updatedPsdPath -ScriptsToProcess $manifestContent.Scripts -NestedModules $updatedScriptPaths -Guid $manifestContent.Guid -Author $manifestContent.Author -CompanyName $manifestContent.CompanyName -Copyright $manifestContent.Copyright -RootModule $manifestContent.RootModule -ModuleVersion $manifestContent.Version -Description $manifestContent.Description -ProcessorArchitecture $manifestContent.ProcessorArchitecture -PowerShellVersion $manifestContent.PowerShellVersion -ClrVersion $manifestContent.ClrVersion -DotNetFrameworkVersion $manifestContent.DotNetFrameworkVersion -PowerShellHostName $manifestContent.PowerShellHostName -PowerShellHostVersion $manifestContent.PowerShellVersion -RequiredModules $manifestContent.RequiredModules -TypesToProcess $manifestContent.TypesToProcess -FormatsToProcess $manifestContent.FormatsToProcess -RequiredAssemblies $manifestContent.RequiredAssemblies -FileList $manifestContent.FileList -ModuleList $manifestContent.ModuleList -FunctionsToExport $manifestContent.FunctionsToExport -AliasesToExport $manifestContent.AliasesToExport -VariablesToExport $manifestContent.VariablesToExport -CmdletsToExport $manifestContent.CmdletsToExport -PrivateData $manifestContent.PrivateData -HelpInfoUri $manifestContent.HelpInfoUri
    }
    elseif (test-path $psdPath) {
		write-host "Using original manifest file $psdPath"
      copy-item $psdPath $outputFolder
    }
    else {
        write-error "Could not find module manifest at $psdPath"
    }

}
 
function Pack-Module {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$sourceFolder,
        [Parameter(Mandatory=$true)]
        [string]$destFolder
    )

    $moduleName = split-path $sourceFolder -leaf
    $packagePath = join-path $destFolder "$moduleName.zip"

    Write-Host "Packing module $moduleName from $sourceFolder to $packagePath"

    ls "$sourceFolder\*"  | out-zip -path $packagePath

    Write-Host "Created module package $packagePath"
}

function Test-Module {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$sourceFolder
    )

    Write-Host "Running tests in $sourceFolder"
}

function out-zip { 
  Param([string]$path) 

  if (-not $path.EndsWith('.zip')) {$path += '.zip'} 

  $7z = join-path $scriptPath "bin\7z.exe"

  $args = @("a", $path) + $input
  write-host "Packing zip $path with cmd line $args"

  & $7z $args

  if ($lastexitcode -ne 0)
  {
    write-error "7zip failed with exit code $lastexitcode"
  }
}