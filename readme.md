# nl.nlsw.ACN

The nl.nlsw.ACN module supports PowerShell and .NET processing
of *Architecture for Control Networks* (ACN) Device Description documents.

The module contains .NET classes for the ACN DDL data model, and PowerShell 
(advanced) functions for input/output processing.

## Downloading the Source Code

You can clone the repository:

```sh
git clone https://github.com/nl-software/nl.nlsw.ACN.git
```
or download the zip file with the latest source.

## Dependencies

- PowerShell module https://github.com/nl-software/nl.nlsw.Document

For running the unit test of the module, you require in addition:

- PowerShell module https://github.com/nl-software/nl.nlsw.TestSuite

## Installation

Install the module in a folder on your `$env:PSModulePath`, e.g. in

```powershell
$Home\Documents\WindowsPowerShell\Modules
```

See [Installing a PowerShell Module] for more information.

## Languages

This module can be used in two ways:

- as (Windows) PowerShell module, using the .NET Framework 4.8 C# compiler
  - the C# files are therefore resticted to C# 5;

- as PowerShell / C# package compiled with the latest .NET SDK.
  - Note: the .csproj files expect the project dependencies in a sibling folder.

## Legal and Licensing

nl.nlsw.ACN is licensed under the [EUPL-1.2 license][].

[Installing a PowerShell Module]: https://docs.microsoft.com/en-us/powershell/scripting/developer/module/installing-a-powershell-module
[EUPL-1.2 license]: https://joinup.ec.europa.eu/collection/eupl/eupl-text-eupl-12