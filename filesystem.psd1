@{
   RootModule        = 'filesystem.psm1'
   ModuleVersion     = '0.0.5'
   FunctionsToExport = @(
     'initialize-emptyDirectory',
     'resolve-relativePath',
     'write-file'
   )
}
