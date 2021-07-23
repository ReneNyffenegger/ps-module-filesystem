@{
   RootModule        = 'filesystem.psm1'
   ModuleVersion     = '0.9'
   FunctionsToExport = @(
     'initialize-emptyDirectory',
     'resolve-relativePath',
     'write-file',
     'test-fileLock',
     'get-openFileProcess',
     'set-locationDocuments'
   )
}
