set-strictMode -version latest
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
