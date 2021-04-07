set-strictMode -version latest

$winApi = add-type -name filesystem -namespace tq84 -passThru -memberDefinition '
  [DllImport("shlwapi.dll", CharSet=CharSet.Auto)]
  public static extern bool PathRelativePathTo(
     [Out] System.Text.StringBuilder pszPath,
     [In]  string pszFrom,
     [In]  System.IO.FileAttributes dwAttrFrom,
     [In]  string pszTo,
     [In]  System.IO.FileAttributes dwAttrTo
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
      $dir,
      $dest
   )

 #
 # The WinAPI function PathRelativePathTo requires directory separators to be backslashes:
 #
   $dir  = $dir -replace '/', '\'
   $dest = $dir -replace '/', '\'

   $relPath = new-object System.Text.StringBuilder 260
   $ok = [tq84.filesystem]::PathRelativePathTo($relPath, $dir, [System.IO.FileAttributes]::Directory, $dest, [System.IO.FileAttributes]::Normal)
   return $relPath.ToString()

}
