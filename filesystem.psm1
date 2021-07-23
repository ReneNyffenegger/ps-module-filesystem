set-strictMode -version latest

$winApi = add-type -name filesystem -namespace tq84 -passThru -memberDefinition '
  [DllImport("shlwapi.dll", CharSet=CharSet.Auto)]
  public static extern bool PathRelativePathTo(
     [Out] System.Text.StringBuilder pszPath,
     [In ] string pszFrom, [In ] System.IO.FileAttributes  dwAttrFrom,
     [In ] string pszTo  , [In ] System.IO.FileAttributes  dwAttrTo
);
'
function initialize-emptyDirectory {

 #
 # Create directory $directoryName
 # If it already exists, clean it
 #

   param (
      [string] $directoryName
   )

   if (test-path $directoryName) {
      try {
       #
       # Try to remove directory.
       # Use -errorAction stop so that catch block
       # is executed if unsuccessful
       #
         remove-item -recurse -force -errorAction stop $directoryName
      }
      catch {
         return $null
      }
   }

   new-item $directoryName -type directory
}

function resolve-relativePath {
 #
 # Inspired by https://get-carbon.org/Resolve-RelativePath.html
 #
 # resolve-relativepath .\dir\subdir .\dir\another\sub\dir\file.txt
 #
   param (
      [parameter (
          mandatory        = $true
       )][string                        ]  $dir  ,


      [parameter (
          mandatory        = $true
       )][string[]                     ]  $dest
   )

 #
 # The WinAPI function PathRelativePathTo requires directory separators to be backslashes:
 #
   $dir  = $dir  -replace '/', '\'
   $dest = $dest -replace '/', '\'

   $relPath = new-object System.Text.StringBuilder 260

   [string[]] $ret = @()

   foreach ($dest_ in $dest) {
      $ok = [tq84.filesystem]::PathRelativePathTo($relPath, $dir, [System.IO.FileAttributes]::Directory, $dest_, [System.IO.FileAttributes]::Normal)
      $ret += $relPath.ToString()
   }

   return $ret
}

function write-file {
 #
 # write-file C:\users\rny\test\more\test\test\test.txt "one`ntwo`nthree"
 # write-file ./foo/bar/baz/utf8.txt      "Bärlauch"
 # write-file ./foo/bar/baz/win-1252.txt  "Bärlauch`nLiberté, Fraternité, Kamillentee"  ( [System.Text.Encoding]::GetEncoding(1252) )
 #
   param (
      [parameter (mandatory=$true)]
      [string] $file,

      [parameter (mandatory=$true)]
      [string] $content,

      [parameter (mandatory=$false)]
      [System.Text.Encoding] $enc = [System.Text.UTF8Encoding]::new($false) # UTF8 without BOM
   )

   $abs_path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($file)
   $abs_dir  = $ExecutionContext.SessionState.Path.ParseParent($abs_path, $null)

   if (! (test-path $abs_dir)) {
      $null = mkdir $abs_dir
   }

   if (test-path $abs_path) {
      remove-item $abs_path
   }

   [System.IO.File]::WriteAllText($abs_path, $content, $enc)
}

function test-fileLock {
  #
  # Inspired by
  #
  # http://mspowershell.blogspot.com/2008/07/locked-file-detection.html
  #
  # Attempts to open a file and trap the resulting error if the file is already open/locked

    param (
       [parameter (mandatory=$true)]
       [string]$filePath
    )

    if (! (test-path $filePath) ) {
       return $null
    }

    $filelocked = $false
    $fileInfo = new-object System.IO.FileInfo $filePath

    trap {
        set-variable -name filelocked -value $true -scope 1
      # $fileLocked = $true
        continue
    }

    $fileStream = $fileInfo.Open( [System.IO.FileMode]::OpenOrCreate,[System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None )
    if ($fileStream) {
        $fileStream.Close()
    }

    $fileLocked
}

function get-openFileProcess {
 #
 # Copied and adapted from
 #   https://github.com/pldmgg/misc-powershell/blob/master/MyFunctions/PowerShellCore_Compatible/Get-FileLockProcess.ps1
 #
   [cmdletBinding()]
    param(
        [parameter(mandatory=$true)]
        [string] $filePath
    )


    if (! $(test-path $filePath)) {
        write-error "The path $filePath was not found! Halting!"
        return
    }

    $csSrc = @"

    using System.Collections.Generic;
    using System.Runtime.InteropServices;
    using System;
    using System.Diagnostics;

    namespace tq84 {

        static public class rstrtmgr {

           [StructLayout(LayoutKind.Sequential)]

            struct RM_UNIQUE_PROCESS {
                public int dwProcessId;
                public System.Runtime.InteropServices.ComTypes.FILETIME ProcessStartTime;
            }

            const int RmRebootReasonNone  =   0;
            const int CCH_RM_MAX_APP_NAME = 255;
            const int CCH_RM_MAX_SVC_NAME =  63;

            enum RM_APP_TYPE {
                RmUnknownApp  =    0,
                RmMainWindow  =    1,
                RmOtherWindow =    2,
                RmService     =    3,
                RmExplorer    =    4,
                RmConsole     =    5,
                RmCritical    = 1000
            }

           [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
            struct RM_PROCESS_INFO {
                public RM_UNIQUE_PROCESS Process;

               [MarshalAs(UnmanagedType.ByValTStr, SizeConst = CCH_RM_MAX_APP_NAME + 1)]
                public string strAppName;

               [MarshalAs(UnmanagedType.ByValTStr, SizeConst = CCH_RM_MAX_SVC_NAME + 1)]
                public string strServiceShortName;

                public RM_APP_TYPE ApplicationType;
                public uint AppStatus;
                public uint TSSessionId;
               [MarshalAs(UnmanagedType.Bool)]
                public bool bRestartable;
            }

           [DllImport("rstrtmgr.dll", CharSet = CharSet.Unicode)]
            static extern int RmRegisterResources(
               uint                pSessionHandle,
               UInt32              nFiles,
               string[]            rgsFilenames,
               UInt32              nApplications,
          [In] RM_UNIQUE_PROCESS[] rgApplications,
               UInt32              nServices,
               string[]            rgsServiceNames);

           [DllImport("rstrtmgr.dll", CharSet = CharSet.Auto)]
            static extern int RmStartSession(out uint pSessionHandle, int dwSessionFlags, string strSessionKey);

           [DllImport("rstrtmgr.dll")]
            static extern int RmEndSession(uint pSessionHandle);

           [DllImport("rstrtmgr.dll")]
            static extern int RmGetList(
                        uint              dwSessionHandle,
              out       uint              pnProcInfoNeeded,
              ref       uint              pnProcInfo,
             [In, Out]  RM_PROCESS_INFO[] rgAffectedApps,
              ref       uint              lpdwRebootReasons);


          //
          // http://msdn.microsoft.com/en-us/library/windows/desktop/aa373661(v=vs.85).aspx
          // https://github.com/wyday/wyupdate/blob/main/frmFilesInUse.cs
          //
             static public List<Process> GetOpenFileProcess(string path) {
                uint handle;
                string key = Guid.NewGuid().ToString();
                List<Process> processes = new List<Process>();

                int res = RmStartSession(out handle, 0, key);
                if (res != 0) throw new Exception("Could not begin restart session.  Unable to determine file locker.");

                try {
                    const int ERROR_MORE_DATA = 234;
                    uint  pnProcInfoNeeded    =   0,
                          pnProcInfo          =   0,
                          lpdwRebootReasons   = RmRebootReasonNone;

                    string[] resources = new string[] { path }; // Just checking on one resource.

                    res = RmRegisterResources(handle, (uint)resources.Length, resources, 0, null, 0, null);

                    if (res != 0) throw new Exception("Could not register resource.");

                    //Note: there's a race condition here -- the first call to RmGetList() returns
                    //      the total number of process. However, when we call RmGetList() again to get
                    //      the actual processes this number may have increased.
                    res = RmGetList(handle, out pnProcInfoNeeded, ref pnProcInfo, null, ref lpdwRebootReasons);

                    if (res == ERROR_MORE_DATA) {

                     // Create an array to store the process results
                        RM_PROCESS_INFO[] processInfo = new RM_PROCESS_INFO[pnProcInfoNeeded];
                        pnProcInfo = pnProcInfoNeeded;

                     // Get the list
                        res = RmGetList(handle, out pnProcInfoNeeded, ref pnProcInfo, processInfo, ref lpdwRebootReasons);
                        if (res == 0) {
                            processes = new List<Process>((int)pnProcInfo);

                         // Enumerate all of the results and add them to the
                         // list to be returned
                            for (int i = 0; i < pnProcInfo; i++) {
                                try
                                {
                                    processes.Add(Process.GetProcessById(processInfo[i].Process.dwProcessId));
                                }
                             // catch the error -- in case the process is no longer running
                                catch (ArgumentException) { }
                            }
                        }
                        else throw new Exception("Could not list processes locking resource.");
                    }
                    else if (res != 0) throw new Exception("Could not list processes locking resource. Failed to get size of result.");
                }
                finally {
                    RmEndSession(handle);
                }

                return processes;
            }
        }
    }
"@


     add-type -typeDef  $csSrc

     return [tq84.rstrtmgr]::GetOpenFileProcess($filePath)

<# TODO: LINUX

    if ($PSVersionTable.Platform -ne $null -and $PSVersionTable.Platform -ne "Win32NT") {
        $lsofOutput = lsof $filePath

        function Parse-lsofStrings ($lsofOutput, $Index) {
            $($lsofOutput[$Index] -split " " | foreach {
                if (![String]::IsNullOrWhiteSpace($_)) {
                    $_
                }
            }).Trim()
        }

        $lsofOutputHeaders = Parse-lsofStrings -lsofOutput $lsofOutput -Index 0
        $lsofOutputValues = Parse-lsofStrings -lsofOutput $lsofOutput -Index 1

        $Result = [pscustomobject]@{}
        for ($i=0; $i -lt $lsofOutputHeaders.Count; $i++) {
            $Result | Add-Member -MemberType NoteProperty -Name $lsofOutputHeaders[$i] -Value $lsofOutputValues[$i]
        }
    }

#>

    $Result

}
function set-locationDocuments() {
   set-location ([System.Environment]::GetFolderPath('MyDocuments'))
}
