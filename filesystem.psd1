@{
   RootModule        = 'filesystem.psm1'
   ModuleVersion     = '0.7'
   FunctionsToExport = @(
     'initialize-emptyDirectory',
     'resolve-relativePath',
     'write-file',
     'test-fileLock'
   )
}
