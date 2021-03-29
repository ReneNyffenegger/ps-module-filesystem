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
      remove-item -recurse -force $directoryName
   }

   new-item $directoryName -type directory

}
