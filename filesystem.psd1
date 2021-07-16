@{
   RootModule        = 'filesystem.psm1'
   ModuleVersion     = '0.8'
   FunctionsToExport = @(
     'initialize-emptyDirectory',
     'resolve-relativePath',
     'write-file',
     'test-fileLock',
     'get-openFileProcessId'
   )
}
