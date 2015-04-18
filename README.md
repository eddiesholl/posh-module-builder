# posh-module-builder

## Overview

These tools aim to streamline the building of powershell modules, in particular building several modules at once. The tools make use of [PsGet](https://github.com/psget/psget), [Pester](https://github.com/pester/Pester) and [PSake](https://github.com/psake/psake) to create an easy and low friction way to get your powershell modules tested, packed and available for consumption.

A key feature facilitated by building several modules at once is including frequently used help scripts in each module. The build phase has particular logic that will convert any relative paths to helper scripts into local paths, and copy those files into the generated module package.

## Installation

Right now, these scripts aren't really packaged in anything like a module or PSGet. The easiest way to start using them is:

* Download the bundle of files from https://github.com/eddiesholl/posh-module-builder/zipball/master
* Create a config file to point to the modules you would like to build. The config file needs to look like:

```
$modulesToPack = @("C:\path\to\modules\module-name-1", "d:\another\path\modules\module-name-2", ".\relativepath\module-name-3")
```

## Example

The run-build.ps1 script is the simplest possible entry point. It takes care of installing prereqs, then will call ```Invoke-psake build-steps.ps1``` to perform the build:

```.\run-build.ps1 -parameters @{"configFile"="C:\path\to\config.ps1"}```

Any [parameters](https://github.com/psake/psake/wiki/How-can-I-pass-parameters-to-my-psake-script%3F) passed to the run-build.ps1 wrapper will be passed to the psake invocation.

To run the build more directly, use a psake command:

```Invoke-psake build-steps.ps1 -parameters @{"configFile"="C:\path\to\config.ps1"}```


At this point you are just running a Psake command, but using the targets defined for you in build-steps.

Current parameters supported include:

* configFile - path to your custom config file
* packagesPath - custom out put path for generated packages. Defaults to ```.\packages```

If you don't specify a path to your config file, it defaults to ```.\config.ps1```


## Features

As mentioned above, the goal of these scripts is to:

* Make it easy to build several modules, particularly as part of a CI build
* Share scripts and embed them in each module. This is to deal with the problems of module dependencies in powershell
* Make it easy for users to install the librayr of generated modules

To facilitate the sharing of scripts, the psd1 file in your module, is parsed. If any items are found in the NestedModules list of your manifest, the paths checked and updated. The files are:

* Located using their relative or absolute paths
* Copied into the module being built
* Their path in the NestedModules property in the generated module manifest is replaced with just their file name

This means when the module is imported locally, your script dependencies will always be found, and are bundled with your module. Happy days.

## Requirements

Each module you point to is expected to contain at least a psd1 file and a psm1 file.

## Notes

When the build runs, it will create a folder .\build to assemble your module. These are then zipped into .\packages. A script is also generated in the .\packages folder, that can be run to import and update all of your shiny new modules!