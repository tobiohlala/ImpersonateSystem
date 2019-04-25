# BSD 3-Clause License
#
# Copy(c) 2019, Tobias Heilig
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copynotice, this
#    list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copynotice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyholder nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYHOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYHOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#requires -RunAsAdministrator

try {
    & {
        $ErrorActionPreference = 'Stop'
        [void] [impsys.win32]
    }
} catch {
   Add-Type -Namespace impsys -Name win32 -MemberDefinition @"
        [DllImport("kernel32.dll", SetLastError=true)]
        public static extern bool CloseHandle(
            IntPtr hHandle);

        [DllImport("kernel32.dll", SetLastError=true)]
        public static extern IntPtr OpenProcess(
            uint processAccess,
            bool bInheritHandle,
            int processId);

        [DllImport("advapi32.dll", SetLastError=true)]
        public static extern bool OpenProcessToken(
            IntPtr ProcessHandle, 
            uint DesiredAccess,
            out IntPtr TokenHandle);

        [DllImport("advapi32.dll", SetLastError=true)]
        public static extern bool DuplicateTokenEx(
            IntPtr hExistingToken,
            uint dwDesiredAccess,
            IntPtr lpTokenAttributes,
            uint ImpersonationLevel,
            uint TokenType,
            out IntPtr phNewToken);

        [DllImport("advapi32.dll", SetLastError=true)]
        public static extern bool ImpersonateLoggedOnUser(
            IntPtr hToken);

        [DllImport("advapi32.dll", SetLastError=true)]
        public static extern bool RevertToSelf();

        [DllImport("advapi32", SetLastError=true, CharSet=CharSet.Unicode)]
        public static extern bool CreateProcessWithTokenW(
            IntPtr hToken,
            int dwLogonFlags,
            string lpApplicationName,
            string lpCommandLine,
            int dwCreationFlags,
            IntPtr lpEnvironment,
            string lpCurrentDirectory,
            IntPtr lpStartupInfo,
            IntPtr lpProcessInformation);
"@
}

function Invoke-AsSystem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [scriptblock]
        $Process,

        [Parameter(Position=1)]
        [object[]]
        $ArgumentList
    )

    $winlogon = Get-Process -Name "winlogon" | Select-Object -First 1

    if (($processHandle = [impsys.win32]::OpenProcess(
            0x400,
            $true,
            [Int32]$winlogon.Id)) -eq [IntPtr]::Zero)
    {
        $err = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        Write-Error "$([ComponentModel.Win32Exception]$err)"
    }

    $tokenHandle = [IntPtr]::Zero
    if (-not [impsys.win32]::OpenProcessToken(
            $processHandle,
            0x0E,
            [ref]$tokenHandle))
    {
        $err = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        Write-Error "$([ComponentModel.Win32Exception]$err)"
    }

    $dupTokenHandle = [IntPtr]::Zero
    if (-not [impsys.win32]::DuplicateTokenEx(
            $tokenHandle,
            0x02000000,
            [IntPtr]::Zero,
            0x02,
            0x01,
            [ref]$dupTokenHandle))
    {
        $err = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        Write-Error "$([ComponentModel.Win32Exception]$err)"
    }

    if (-not [impsys.win32]::ImpersonateLoggedOnUser(
            $dupTokenHandle))
    {
        $err = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        Write-Error "$([ComponentModel.Win32Exception]$err)"
    }

    & $Process @ArgumentList

    if(-not [impsys.win32]::RevertToSelf())
    {
        $err = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        Write-Error "$([ComponentModel.Win32Exception]$err)"
    }

    <#
        .SYNOPSIS
        Impersonate SYSTEM.

        .DESCRIPTION
        Impersonate Windows built-in SYSTEM account and execute commands on its behalf.

        .PARAMETER Process
        The script block to be executed as SYSTEM.

        .PARAMETER ArgumentList
        Optional list of arguments to the scriptblock.

        .COMPONENT
        Win32

        .NOTES
        Requires to be run as administrator.

        .EXAMPLE
        Invoke-AsSystem { [System.Environment]::UserName }

        .EXAMPLE
        Invoke-AsSystem { param($x,$y) $x + $y } -ArgumentList 1,2
    #>
}
