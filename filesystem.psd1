@{
   RootModule        = 'filesystem.psm1'
   ModuleVersion     = '0.0.4'
   FunctionsToExport = @(
     'initialize-emptyDirectory',
     'resolve-relativePath',
     'write-file'
   )
}
