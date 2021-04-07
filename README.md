# ImpersonateSystem

[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/ImpersonateSystem.svg)](https://www.powershellgallery.com/packages/ImpersonateSystem) ![](https://img.shields.io/badge/supported%20windows%20versions-7%2F8%2F10-green.svg)

Impersonate Windows built-in SYSTEM account.

## Description

Impersonate Windows built-in SYSTEM account and execute commands on its behalf by invoking a scriptblock.

**Note:** Requires to be run as `Administrator`.

## Installation

Install from [PowerShell Gallery](https://www.powershellgallery.com/packages/ImpersonateSystem)

```Powershell
Install-Module -Name ImpersonateSystem
```
or
```Shell
git clone https://github.com/tobiohlala/ImpersonateSystem
```

## Usage

```Powershell
Import-Module ImpersonateSystem

Invoke-AsSystem { [System.Environment]::UserName }
```

## Examples

```Powershell
Get-Help Invoke-AsSystem -Examples
```
