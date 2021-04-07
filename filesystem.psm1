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
   $dir  = $dir  -replace '/', '\'
   $dest = $dest -replace '/', '\'

   $relPath = new-object System.Text.StringBuilder 260
   $ok = [tq84.filesystem]::PathRelativePathTo($relPath, $dir, [System.IO.FileAttributes]::Directory, $dest, [System.IO.FileAttributes]::Normal)
   return $relPath.ToString()

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
