@{
   RootModule        = 'filesystem.psm1'
   ModuleVersion     = '0.0.6'
   FunctionsToExport = @(
     'initialize-emptyDirectory',
     'resolve-relativePath',
     'write-file'
   )
}
