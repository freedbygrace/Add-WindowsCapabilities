#Requires -Version 3

<#
    .SYNOPSIS
    This script performs the automated adding 1 or more features on demand (FODs) to a currently running operating system, a mounted windows image, or an image that has been deployed to a volume while in WindowsPE.
          
    .DESCRIPTION
    This script allows the features on demand to be added to images intended to be used for in-place upgrades and/or bare metal deployment so that the features are enabled before the operating system has even booted for the first time.
    This script will also save headaches fighting with Windows Update in domain environments that enforce WSUS which causes errors. In short, these commands were really built for consumer environments so this script is born out of that limitation.

    .PARAMETER Online
    Informs the script to add capabililties to the currently running operating system.

    .PARAMETER Offline
    Informs the script to add capabilities to a mounted windows image or a windows image that has been expanded onto a disk, such as during MDT or SCCM operating system deployment.

    .PARAMETER ImagePath
    The directory path to the mounted windows image or the drive letter of a windows image that has been expanded onto a disk while in WindowsPE.

    .PARAMETER CapabilitiesToAdd
    A valid regular expression. Allows to enable mutiple capabilities by using a regular expression.
    Example: .*NetFX3.*|^SNMP.*Client.*|.*WMI.*SNMP.*Provider.*Client.*
    Meaning: Anything with "NetFX3" in the capability name; Anything that begins with SNMP and has the word "Client" in the capability name; Anything that has the words WMI, SNMP, Provider, and Client in the capability name.

    .PARAMETER Source
    1 or more valid folder paths. These locations must contain the valid feature on demand files that are relevant to your operating system, release ID, and architecture. Example: Windows 10 1809 X64
    Functionality exists in this script to make this easier. If you look at the folder "WindowsCapabilities" included with this script, and create a folder path in there like the following, they will be automatically found by the script.
    ScriptPath\WindowsCapabilities\1809\X64\<Place Feature On Demand Files Here>

    .PARAMETER LogDir
    A valid folder path. If the folder does not exist, it will be created. This parameter can also be specified by the alias "LogPath".

    .PARAMETER ContinueOnError
    Ignore failures.
          
    .EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -File "%FolderPathContainingScript%\Add-WindowsCapabilities.ps1" -Online -Source "MyFODSourcePath" -FODs ".*NetFX3.*|^SNMP.*Client.*|.*WMI.*SNMP.*Provider.*Client.*"

    .EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -File "%FolderPathContainingScript%\Add-WindowsCapabilities.ps1" -Offline -ImagePath "$($Env:SystemDrive):\YourWindowsImageMountPath" -FODs ".*NetFX3.*|^SNMP.*Client.*|.*WMI.*SNMP.*Provider.*Client.*"
  
    .NOTES
    Unfortunately you cannot just copy various files out of the features on demand ISO and expect the powershell commands to work. Some features on demand have other dependency file(s), etc.
    and all of this is figured out when trying to install the feature. You need to use dism.exe (There is not a powershell native equivalent command currently) and use the following code snippet to export the appropriate files for this process to work.

    ###Begin Dism.exe example command output###
    /Export-Source {/CapabilityName:<name_in_image> | /Recipe:<path_to_recipe_file>}
      /Source:<source> /Target:<target> [/IncludeImageCapabilities]

      Export a set of capabilities into a new repository.

      Use the /CapabilityName to specify the capability you would like to
      export. Multiple /CapabilityName arguments can be used. You can use /Recipe
      instead of /CapabilityName to specify multiple capabilities at a time.
      Use the /Source argument to specify the location of the source repository.
      Use the /Target to specify the location of the new repository.
      Use the /IncludeImageCapabilities to export image capabilities into the
      new repository.

    Examples:
      Dism /Image:C:\test\offline /Export-Source /Source:C:\test\source
        /Target:C:\test\target /CapabilityName:Language.Basic~~~en-US~0.0.1.0

      Dism /Image:C:\test\offline /Export-Source /Source:C:\test\source
        /Target:C:\test\target /Recipe:C:\test\recipe\recipe.xml
    ###End Dism.exe example command output###

    ###Begin Code Snippet###
      ###Make sure to download the Feature On Demand (FOD) iso from the Microsoft Volume Licensing Service Center before beginning.###
        
        ###https://www.microsoft.com/Licensing/servicecenter/Home.aspx###

      ###This is the root path of contents of the Features On Demand (FOD) iso (You could also mount the ISO and specify the drive letter)
        [System.IO.DirectoryInfo]$FODSourcePath = "E:\Deployment\ISOs\FeaturesOnDemand\SW_DVD9_NTRL_Win_10_2004_64Bit_MultiLang_FOD_1_X22-21311"
    
      ###This is where you want the files to be exported, the directory will be created if it does not exist###
        [System.IO.DirectoryInfo]$FODExportPath = "$($Env:SystemDrive)\FeaturesOnDemand\2004"
        If ($FODExportPath.Exists -eq $False) {$Null = [System.IO.Directory]::CreateDirectory($FODExportPath.FullName)}
    
      [System.IO.FileInfo]$WIMPath = "D:\install.wim"
      [System.IO.DirectoryInfo]$WIMMountPath = "$($Env:Temp.TrimEnd('\'))\$([System.GUID]::NewGUID().ToString().ToUpperInvariant())"
      If ($WIMMountPath.Exists -eq $False) {$Null = [System.IO.Directory]::CreateDirectory($WIMMountPath.FullName)}
      
      Import-Module DISM -Force
      
      $WindowsImageProperties = Get-WindowsImage -ImagePath "$($WIMPath.FullName)" | Where-Object {($_.ImageName -imatch "^.*Enterprise$")}
      
      Mount-WindowsImage -ImagePath "$($WIMPath.FullName)" -Path "$($WIMMountPath.FullName)" -Index "$($WindowsImageProperties.ImageIndex)" -ReadOnly
    
      [System.IO.FileInfo]$BinaryPath = "$([System.Environment]::SystemDirectory)\dism.exe"
      
      [String[]]$CapabilityNames = @()
      $CapabilityNames += "/CapabilityName:`"Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0`""
      $CapabilityNames += "/CapabilityName:`"NetFX3~~~~`""
      $CapabilityNames += "/CapabilityName:`"WMI-SNMP-Provider.Client~~~~0.0.1.0`""
      $CapabilityNames += "/CapabilityName:`"SNMP.Client~~~~0.0.1.0`""

      [String]$CapabilityNamesAsString = $CapabilityNames -Join ' '

      [System.IO.FileInfo]$LogPath = "$($Env:Temp.TrimEnd('\'))\$($BinaryPath.BaseName)_ExportFODSource.log"

      [String]$BinaryParameters = "/Image:`"$($WIMMountPath.FullName)`" /Export-Source /Source:`"$($FODSourcePath.FullName)`" /Target:`"$($FODExportPath.FullName)`" $($CapabilityNamesAsString) /LogPath:`"$($LogPath.FullName)`""
      [System.IO.FileInfo]$BinaryStandardOutputPath = "$($Env:Temp.TrimEnd('\'))\$($BinaryPath.BaseName)_StandardOutput.log"
      [System.IO.FileInfo]$BinaryStandardErrorPath = "$($Env:Temp.TrimEnd('\'))\$($BinaryPath.BaseName)_StandardError.log"

      Write-Verbose -Message "Binary Path: $($BinaryPath.FullName)" -Verbose
      Write-Verbose -Message "Binary Parameters: $($BinaryParameters)" -Verbose
      Write-Verbose -Message "Standard Output Path: $($BinaryStandardOutputPath.FullName)" -Verbose
      Write-Verbose -Message "Standard Error Path: $($BinaryStandardErrorPath.FullName)" -Verbose
      
      $ExecuteBinary = Start-Process -FilePath "$($BinaryPath.FullName)" -ArgumentList "$($BinaryParameters)" -WindowStyle Hidden -RedirectStandardOutput "$($BinaryStandardOutputPath)" -RedirectStandardError "$($BinaryStandardErrorPath)" -Wait -PassThru
      
      Write-Verbose -Message "Binary Exit Code = $($ExecuteBinary.ExitCode)" -Verbose

      Dismount-WindowsImage -Path "$($WIMMountPath.FullName)" -Discard

    ###End Code Snippet###
          
    .LINK
    https://docs.microsoft.com/en-us/powershell/module/dism/get-windowscapability?view=win10-ps

    .LINK
    https://docs.microsoft.com/en-us/powershell/module/dism/add-windowscapability?view=win10-ps

    .LINK
    https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/features-on-demand-v2--capabilities

    .LINK
    https://forums.mydigitallife.net/threads/how-to-export-a-set-of-capabilities-into-a-new-repository-better-use-ready-fod-iso.80739/
    
    .LINK
    https://p0w3rsh3ll.wordpress.com/2019/05/24/quick-post-dism-and-features-on-demand-fod/
#>

[CmdletBinding()]
    Param
        (        	     
            [Parameter(Mandatory=$False, ParameterSetName="Online")]
            [Switch]$Online,

            [Parameter(Mandatory=$False, ParameterSetName="Offline")]
            [Switch]$Offline,

            [Parameter(Mandatory=$False, ParameterSetName="Offline")]
            [ValidateNotNullOrEmpty()]
            [ValidateScript({($_ -imatch '^[a-zA-Z][\:]\\{1,}$') -or ($_ -imatch '^[a-zA-Z][\:]\\.*?[^\\]$')})]
            [System.IO.DirectoryInfo]$ImagePath,
            
            [Parameter(Mandatory=$False)]
            [ValidateNotNullOrEmpty()]
            [Alias('FODs')]
            [Regex]$CapabilitiesToAdd = '.*NetFX3.*|^SNMP.*Client.*|.*WMI.*SNMP.*Provider.*Client.*',

            [Parameter(Mandatory=$False)]
            [ValidateNotNullOrEmpty()]
            [ValidateScript({(($_ -imatch '^[a-zA-Z][\:]\\$') -or ($_ -imatch '^[a-zA-Z][\:]\\.*$')) -and (Test-Path -Path $_.FullName)})]
            [System.IO.DirectoryInfo[]]$Source,

            [Parameter(Mandatory=$False)]
            [ValidateNotNullOrEmpty()]
            [ValidateScript({($_ -imatch '^[a-zA-Z][\:]\\.*?[^\\]$') -or ($_ -imatch "^\\(?:\\[^<>:`"/\\|?*]+)+$")})]
            [System.IO.DirectoryInfo]$LogDir,
            
            [Parameter(Mandatory=$False)]
            [Switch]$ContinueOnError
        )

#Define Default Action Preferences
    $Script:DebugPreference = 'SilentlyContinue'
    $Script:ErrorActionPreference = 'Stop'
    $Script:VerbosePreference = 'SilentlyContinue'
    $Script:WarningPreference = 'Continue'
    $Script:ConfirmPreference = 'None'
    
#Load WMI Classes
  $Baseboard = Get-WmiObject -Namespace "root\CIMv2" -Class "Win32_Baseboard" -Property * | Select-Object -Property *
  $Bios = Get-WmiObject -Namespace "root\CIMv2" -Class "Win32_Bios" -Property * | Select-Object -Property *
  $ComputerSystem = Get-WmiObject -Namespace "root\CIMv2" -Class "Win32_ComputerSystem" -Property * | Select-Object -Property *
  $OperatingSystem = Get-WmiObject -Namespace "root\CIMv2" -Class "Win32_OperatingSystem" -Property * | Select-Object -Property *

#Retrieve property values
  $OSArchitecture = $($OperatingSystem.OSArchitecture).Replace("-bit", "").Replace("32", "86").Insert(0,"x").ToUpper()

#Define variable(s)
  $DateTimeLogFormat = 'dddd, MMMM dd, yyyy hh:mm:ss tt'  ###Monday, January 01, 2019 10:15:34 AM###
  [ScriptBlock]$GetCurrentDateTimeLogFormat = {(Get-Date).ToString($DateTimeLogFormat)}
  $DateTimeFileFormat = 'yyyyMMdd_hhmmsstt'  ###20190403_115354AM###
  [ScriptBlock]$GetCurrentDateTimeFileFormat = {(Get-Date).ToString($DateTimeFileFormat)}
  [System.IO.FileInfo]$ScriptPath = "$($MyInvocation.MyCommand.Definition)"
  [System.IO.DirectoryInfo]$ScriptDirectory = "$($ScriptPath.Directory.FullName)"
  [System.IO.DirectoryInfo]$FunctionsDirectory = "$($ScriptDirectory.FullName)\Functions"
  [System.IO.DirectoryInfo]$ModulesDirectory = "$($ScriptDirectory.FullName)\Modules"
  [System.IO.DirectoryInfo]$ToolsDirectory = "$($ScriptDirectory.FullName)\Tools"
  [System.IO.DirectoryInfo]$ToolsDirectoryGeneric = "$($ScriptDirectory.FullName)\Tools\All"
  [System.IO.DirectoryInfo]$ToolsDirectoryArchSpecific = "$($ScriptDirectory.FullName)\Tools\$($OSArchitecture)"
  $IsWindowsPE = Test-Path -Path 'HKLM:\SYSTEM\ControlSet001\Control\MiniNT' -ErrorAction SilentlyContinue

#Log any useful information
  $LogMessage = "IsWindowsPE = $($IsWindowsPE.ToString())`r`n"
  Write-Verbose -Message "$($LogMessage)" -Verbose

  $LogMessage = "Script Path = $($ScriptPath.FullName)`r`n"
  Write-Verbose -Message "$($LogMessage)" -Verbose
  
  $LogMessage = "Script Directory = $($ScriptDirectory.FullName)`r`n"
  Write-Verbose -Message "$($LogMessage)" -Verbose
	
#Log task sequence variables if debug mode is enabled within the task sequence
  Try
    {
        [System.__ComObject]$TSEnvironment = New-Object -ComObject "Microsoft.SMS.TSEnvironment"
              
        If ($TSEnvironment -ine $Null)
          {
              $IsRunningTaskSequence = $True
          }
    }
  Catch
    {
        $IsRunningTaskSequence = $False
    }

#Determine the default logging path if the parameter is not specified and is not assigned a default value
  If (($PSBoundParameters.ContainsKey('LogDir') -eq $False) -and ($LogDir -ieq $Null))
    {
        If ($IsRunningTaskSequence -eq $True)
          {
              [String]$_SMSTSLogPath = "$($TSEnvironment.Value('_SMSTSLogPath'))"
                    
              If ([String]::IsNullOrEmpty($_SMSTSLogPath) -eq $False)
                {
                    [System.IO.DirectoryInfo]$TSLogDirectory = "$($_SMSTSLogPath)"
                }
              Else
                {
                    [System.IO.DirectoryInfo]$TSLogDirectory = "$($Env:Windir)\Temp\SMSTSLog"
                }
                     
              [System.IO.DirectoryInfo]$LogDir = "$($TSLogDirectory.FullName)\$($ScriptPath.BaseName)"
          }
        ElseIf ($IsRunningTaskSequence -eq $False)
          {
              [System.IO.DirectoryInfo]$LogDir = "$($Env:Windir)\Logs\Software\$($ScriptPath.BaseName)"
          }
    }

#Start transcripting (Logging)
  Try
    {
        [System.IO.FileInfo]$ScriptLogPath = "$($LogDir.FullName)\$($ScriptPath.BaseName)_$($GetCurrentDateTimeFileFormat.Invoke()).log"
        If ($ScriptLogPath.Directory.Exists -eq $False) {[Void][System.IO.Directory]::CreateDirectory($ScriptLogPath.Directory.FullName)}
        Start-Transcript -Path "$($ScriptLogPath.FullName)" -IncludeInvocationHeader -Force -Verbose
    }
  Catch
    {
        If ([String]::IsNullOrEmpty($_.Exception.Message)) {$ExceptionMessage = "$($_.Exception.Errors.Message)"} Else {$ExceptionMessage = "$($_.Exception.Message)"}
          
        $ErrorMessage = "[Error Message: $($ExceptionMessage)][ScriptName: $($_.InvocationInfo.ScriptName)][Line Number: $($_.InvocationInfo.ScriptLineNumber)][Line Position: $($_.InvocationInfo.OffsetInLine)][Code: $($_.InvocationInfo.Line.Trim())]"
        Write-Error -Message "$($ErrorMessage)"
    }

#Log any useful information
  $LogMessage = "IsWindowsPE = $($IsWindowsPE.ToString())"
  Write-Verbose -Message "$($LogMessage)" -Verbose

  $LogMessage = "Script Path = $($ScriptPath.FullName)"
  Write-Verbose -Message "$($LogMessage)" -Verbose

  $DirectoryVariables = Get-Variable | Where-Object {($_.Value -ine $Null) -and ($_.Value -is [System.IO.DirectoryInfo])}
  
  ForEach ($DirectoryVariable In $DirectoryVariables)
    {
        $LogMessage = "$($DirectoryVariable.Name) = $($DirectoryVariable.Value.FullName)"
        Write-Verbose -Message "$($LogMessage)" -Verbose
    }

#region Import Dependency Modules
$Modules = Get-Module -Name "$($ModulesDirectory.FullName)\*" -ListAvailable -ErrorAction Stop 

$ModuleGroups = $Modules | Group-Object -Property @('Name')

ForEach ($ModuleGroup In $ModuleGroups)
  {
      $LatestModuleVersion = $ModuleGroup.Group | Sort-Object -Property @('Version') -Descending | Select-Object -First 1
      
      If ($LatestModuleVersion -ine $Null)
        {
            $LogMessage = "Attempting to import dependency powershell module `"$($LatestModuleVersion.Name) [Version: $($LatestModuleVersion.Version.ToString())]`". Please Wait..."
            Write-Verbose -Message "$($LogMessage)" -Verbose
            Import-Module -Name "$($LatestModuleVersion.Path)" -Global -DisableNameChecking -Force -ErrorAction Stop
        }
  }
#endregion

#region Dot Source Dependency Scripts
#Dot source any additional script(s) from the functions directory. This will provide flexibility to add additional functions without adding complexity to the main script and to maintain function consistency.
  Try
    {
        If ($FunctionsDirectory.Exists -eq $True)
          {
              [String[]]$AdditionalFunctionsFilter = "*.ps1"
        
              $AdditionalFunctionsToImport = Get-ChildItem -Path "$($FunctionsDirectory.FullName)" -Include ($AdditionalFunctionsFilter) -Recurse -Force | Where-Object {($_ -is [System.IO.FileInfo])}
        
              $AdditionalFunctionsToImportCount = $AdditionalFunctionsToImport | Measure-Object | Select-Object -ExpandProperty Count
        
              If ($AdditionalFunctionsToImportCount -gt 0)
                {                    
                    ForEach ($AdditionalFunctionToImport In $AdditionalFunctionsToImport)
                      {
                          Try
                            {
                                $LogMessage = "Attempting to dot source dependency script `"$($AdditionalFunctionToImport.Name)`". Please Wait...`r`n`r`nScript Path: `"$($AdditionalFunctionToImport.FullName)`""
                                Write-Verbose -Message "$($LogMessage)" -Verbose
                          
                                . "$($AdditionalFunctionToImport.FullName)"
                            }
                          Catch
                            {
                                $ErrorMessage = "[Error Message: $($_.Exception.Message)]`r`n`r`n[ScriptName: $($_.InvocationInfo.ScriptName)]`r`n[Line Number: $($_.InvocationInfo.ScriptLineNumber)]`r`n[Line Position: $($_.InvocationInfo.OffsetInLine)]`r`n[Code: $($_.InvocationInfo.Line.Trim())]"
                                Write-Error -Message "$($ErrorMessage)" -Verbose
                            }
                      }
                }
          }
    }
  Catch
    {
        $ErrorMessage = "[Error Message: $($_.Exception.Message)]`r`n`r`n[ScriptName: $($_.InvocationInfo.ScriptName)]`r`n[Line Number: $($_.InvocationInfo.ScriptLineNumber)]`r`n[Line Position: $($_.InvocationInfo.OffsetInLine)]`r`n[Code: $($_.InvocationInfo.Line.Trim())]"
        Write-Error -Message "$($ErrorMessage)" -Verbose            
    }
#endregion

#region Load Dependencies
  If ($IsWindowsPE -eq $True)
    {
        $DLLsToLoad = Get-ChildItem -Path "$($ToolsDirectoryGeneric.FullName)" -Filter '*.dll' -Recurse -Force | Where-Object {($_ -is [System.IO.FileInfo])}

        ForEach ($DLLToLoad In $DLLsToLoad)
          {
              $LogMessage = "Attempting to load DLL module `"$($DLLToLoad.FullName)`". Please Wait..."
              Write-Verbose -Message "$($LogMessage)" -Verbose
        
              $AssemblyBytes = [System.IO.File]::ReadAllBytes($DLLToLoad.FullName)
              $AssemblyBytesBase64 = [System.Convert]::ToBase64String($AssemblyBytes)
              $Null = [System.Reflection.Assembly]::Load([System.Convert]::FromBase64String($AssemblyBytesBase64))
          }
    }
#endregion

#Perform script action(s)
  Try
    {                          
        #Tasks defined within this block will only execute if a task sequence is running
          If (($IsRunningTaskSequence -eq $True))
            {
                If (($PSBoundParameters.ContainsKey('ImagePath') -eq $False) -and ($ImagePath -eq $Null))
                  {
                      [System.IO.DirectoryInfo]$ImagePath = "$($TSEnvironment.Value('OSDisk'))\"
                  }
            }
    
          $LogMessage = "Parameter Set Name = $($PSCmdlet.ParameterSetName.ToString())"
          Write-Verbose -Message "$($LogMessage)" -Verbose
          
          If (($PSCmdlet.ParameterSetName -imatch "Online") -and ($IsWindowsPE -eq $False))
            {
                [String]$XReleaseID = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "ReleaseID").ReleaseID
                $XEditionID = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "EditionID").EditionID
                $XBuildLabEX = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "BuildLabEX").BuildLabEX
                $XCurrentBuildNumber = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "CurrentBuildNumber").CurrentBuildNumber
                $WindowsImageVersion = $OperatingSystem.Version
            }
          ElseIf ($PSCmdlet.ParameterSetName -imatch "Offline")
            {
                [System.IO.FileInfo]$RegistryHivePath = "$($ImagePath.FullName.TrimEnd('\'))\Windows\System32\Config\Software"

                $LogMessage = "Registry Hive Path = $($RegistryHivePath.FullName)"
                Write-Verbose -Message "$($LogMessage)" -Verbose
                
                $RegistryHive = [Registry.RegistryHiveOnDemand]::New($RegistryHivePath.FullName)
              
                $RegistryValues = @()
                
                [String[]]$RegistryHiveKeyPaths = 'Root\Microsoft\Windows NT\CurrentVersion'

                ForEach ($RegistryHiveKeyPath In $RegistryHiveKeyPaths)
                  {
                      $RegistryKeyPathValues = $RegistryHive.GetKey($RegistryHiveKeyPath).Values
                      $RegistryValues += ($RegistryKeyPathValues)
                  }
                        
                ForEach ($RegistryValue In $RegistryValues)
                  {
                      Try
                        {
                            If ($RegistryValue.ValueName.ToString().Trim() -imatch "^ReleaseID$|^EditionID$|^BuildLabEX$|^CurrentBuildNumber$")
                              {
                                  $VariableName = "X$($RegistryValue.ValueName.ToString().Trim())"
                                  $VariableDescription = "Contains the value of `"$($VariableName)`" for the windows image applied to `"$($ImagePath.FullName)`""

                                  Switch ($RegistryValue.ValueType)
                                    {
                                        {$_ -imatch 'RegSZ'} {$VariableValue = "$($RegistryValue.ValueData.ToString().Trim())"}
                                        {$_ -imatch 'RegDword'} {$VariableValue = [System.Convert]::ToString("0x$($RegistryValue.ValueData)", 10)}
                                        {$_ -imatch 'RegQword'} {$VariableValue = [System.Convert]::ToInt64(($RegistryValue.ValueData), 16)}     
                                    }

                                  $CreateVariableFromRegistryValue = New-Variable -Name "$($VariableName)" -Value ($VariableValue) -Description "$($VariableDescription)" -Force -Verbose
                              }
                        }
                      Catch
                        {
                            If ([String]::IsNullOrEmpty($_.Exception.Message)) {$ExceptionMessage = "$($_.Exception.Errors.Message)"} Else {$ExceptionMessage = "$($_.Exception.Message)"}

                            $WarningMessage = "[Error Message: $($ExceptionMessage)][ScriptName: $($_.InvocationInfo.ScriptName)][Line Number: $($_.InvocationInfo.ScriptLineNumber)][Line Position: $($_.InvocationInfo.OffsetInLine)][Code: $($_.InvocationInfo.Line.Trim())]"
                            Write-Error -Message "$($WarningMessage)" -Verbose
                        }
                  }

                [System.IO.FileInfo]$WindowsImageCommandPromptPath = "$($ImagePath.FullName.TrimEnd('\'))\Windows\System32\cmd.exe"
                
                [Version]$WindowsImageVersion = "$($WindowsImageCommandPromptPath.VersionInfo.ProductVersionRaw.Major).$($WindowsImageCommandPromptPath.VersionInfo.ProductVersionRaw.Minor).$($XCurrentBuildNumber)"
            }
        
        #Tasks defined here will execute whether a task sequence is running or not
          $LogMessage = "Image Version = $($WindowsImageVersion.ToString())"
          Write-Verbose -Message "$($LogMessage)" -Verbose

          $LogMessage = "Image Release ID = $($XReleaseID)"
          Write-Verbose -Message "$($LogMessage)" -Verbose

          $LogMessage = "Image Edition = $($XEditionID)"
          Write-Verbose -Message "$($LogMessage)" -Verbose

          Switch ($XBuildLabEX)
            {
                {$_ -inotmatch '.*amd64.*'} {$XWindowsImageArchitecture = 'X86'}
                {$_ -imatch '.*amd64.*'} {$XWindowsImageArchitecture = 'X64'}
            }

          $LogMessage = "Image Architecture = $($XWindowsImageArchitecture)"
          Write-Verbose -Message "$($LogMessage)" -Verbose

          If (($PSBoundParameters.ContainsKey('Source') -eq $False) -and ($Source -ieq $Null))
            {
                [System.IO.DirectoryInfo[]]$Source = @()
                $Source += "$($ScriptDirectory.FullName)\WindowsCapabilities\$($XReleaseID)\$($XWindowsImageArchitecture)"
            }
   
          $LogMessage = "Source = $($Source.FullName)"
          Write-Verbose -Message "$($LogMessage)" -Verbose

          If (($PSCmdlet.ParameterSetName -imatch "Online") -and ($IsWindowsPE -eq $False))
            {
                [Hashtable]$GetWindowsCapabilityParameters = @{
                                                                  Online = [Switch]::Present;
                                                                  LimitAccess = [Switch]::Present
                                                              }

                [Hashtable]$AddWindowsCapabilityParameters = @{
                                                                  Online = [Switch]::Present;
                                                                  Source = ($Source.FullName);
                                                                  LimitAccess = [Switch]::Present;
                                                                  LogLevel = "Errors";
                                                                  Verbose = [Switch]::Present
                                                              }
            }
          ElseIf ($PSCmdlet.ParameterSetName -imatch "Offline")
            {
                [Hashtable]$GetWindowsCapabilityParameters = @{
                                                                  Path = "$($ImagePath.FullName)";
                                                                  LimitAccess = [Switch]::Present
                                                              }

                [Hashtable]$AddWindowsCapabilityParameters = @{
                                                                  Path = "$($ImagePath.FullName)";
                                                                  Source = ($Source.FullName);
                                                                  LimitAccess = [Switch]::Present;
                                                                  LogLevel = "Errors";
                                                                  Verbose = [Switch]::Present
                                                              }
            }

          $LogMessage = "Attempting to determine the available windows capabilities. Please Wait..."
          Write-Verbose -Message "$($LogMessage)" -Verbose
                      
          $WindowsCapabilities = Get-WindowsCapability @GetWindowsCapabilityParameters | Select-Object -Property @('*') | Sort-Object -Property @('Name')
                    
          $WindowsCapabilitiesToAdd = $WindowsCapabilities | Where-Object {($_.Name -imatch $CapabilitiesToAdd.ToString())}
                    
          $WindowsCapabilitiesToAddCount = $WindowsCapabilitiesToAdd | Measure-Object | Select-Object -ExpandProperty Count
    
          $Counter = 1
                    
          ForEach ($WindowsCapabilityToAdd In $WindowsCapabilitiesToAdd)
              {
                  If ($WindowsCapabilityToAdd.State -inotmatch 'Installed')
                    {
                        Try
                          {
                              [Int]$ProgressID = 1
                              [String]$ActivityMessage = "Add-WindowsCapability $($WindowsCapabilityToAdd.Name) [State: $($WindowsCapabilityToAdd.State)]"
                              [String]$StatusMessage = "Add-WindowsCapability $($WindowsCapabilityToAdd.Name) [State: $($WindowsCapabilityToAdd.State)] ($($Counter.ToString()) of $($WindowsCapabilitiesToAddCount.ToString()))"
                              [Int]$PercentComplete = (($Counter / $WindowsCapabilitiesToAddCount) * 100)

                              $LogMessage = "$($StatusMessage). Please Wait..."
                              Write-Verbose -Message "$($LogMessage)" -Verbose
                              
                              Write-Progress -ID ($ProgressID) -Activity ($ActivityMessage) -Status ($StatusMessage) -PercentComplete ($PercentComplete)

                              [System.IO.FileInfo]$WindowsCapabilityToAddLogPath = "$($LogDir.FullName)\$($WindowsCapabilityToAdd.Name).log"

                              If ($WindowsCapabilityToAddLogPath.Directory.Exists -eq $False) {$Null = [System.IO.Directory]::CreateDirectory($WindowsCapabilityToAddLogPath.Directory.FullName)}

                              $LogMessage = "Log Path = `"$($WindowsCapabilityToAddLogPath.FullName)`""
                              Write-Verbose -Message "$($LogMessage)" -Verbose
                              
                              $AddWindowsCapability = Add-WindowsCapability @AddWindowsCapabilityParameters -Name "$($WindowsCapabilityToAdd.Name)" -LogPath "$($WindowsCapabilityToAddLogPath.FullName)"

                              If ($? -eq $True)
                                {
                                    $LogMessage = "Addition of the `"$($WindowsCapabilityToAdd.Name)`" windows capability was successful!"
                                    Write-Verbose -Message "$($LogMessage)" -Verbose
                                }
                              ElseIf ($? -eq $False)
                                {
                                    $LogMessage = "Addition of the `"$($WindowsCapabilityToAdd.Name)`" windows capability was unsuccessful!"
                                    Write-Error -Message "$($LogMessage)" -Verbose
                                }
                          }
                        Catch
                          {
                              If ([String]::IsNullOrEmpty($_.Exception.Message)) {$ExceptionMessage = "$($_.Exception.Errors.Message)"} Else {$ExceptionMessage = "$($_.Exception.Message)"}
          
                              $WarningMessage = "[Error Message: $($ExceptionMessage)][ScriptName: $($_.InvocationInfo.ScriptName)][Line Number: $($_.InvocationInfo.ScriptLineNumber)][Line Position: $($_.InvocationInfo.OffsetInLine)][Code: $($_.InvocationInfo.Line.Trim())]"
                              Write-Error -Message "$($WarningMessage)" -Verbose
                          }
                    }
                  ElseIf ($WindowsCapabilityToAdd.State -imatch 'Installed')
                    {
                        $LogMessage = "[Windows Capability ($($Counter.ToString()) of $($WindowsCapabilitiesToAddCount.ToString()))] - `"$($WindowsCapabilityToAdd.Name)`" [State: $($WindowsCapabilityToAdd.State)]. No further action will be taken."
                        Write-Verbose -Message "$($LogMessage)" -Verbose
                    }

                  $Counter++
              }

        #Tasks defined here will execute whether only if a task sequence is not running
          If ($IsRunningTaskSequence -eq $False)
            {
                $WarningMessage = "There is no task sequence running.`r`n"
                Write-Warning -Message "$($WarningMessage)" -Verbose
            }
            
        #Stop transcripting (Logging)
          Try
            {
                Stop-Transcript -Verbose
            }
          Catch
            {
                If ([String]::IsNullOrEmpty($_.Exception.Message)) {$ExceptionMessage = "$($_.Exception.Errors.Message)"} Else {$ExceptionMessage = "$($_.Exception.Message)"}
          
                $ErrorMessage = "[Error Message: $($ExceptionMessage)][ScriptName: $($_.InvocationInfo.ScriptName)][Line Number: $($_.InvocationInfo.ScriptLineNumber)][Line Position: $($_.InvocationInfo.OffsetInLine)][Code: $($_.InvocationInfo.Line.Trim())]"
                Write-Error -Message "$($ErrorMessage)"
            }
    }
  Catch
    {
        If ([String]::IsNullOrEmpty($_.Exception.Message)) {$ExceptionMessage = "$($_.Exception.Errors.Message -Join "`r`n`r`n")"} Else {$ExceptionMessage = "$($_.Exception.Message)"}
          
        $ErrorMessage = "[Error Message: $($ExceptionMessage)]`r`n`r`n[ScriptName: $($_.InvocationInfo.ScriptName)]`r`n[Line Number: $($_.InvocationInfo.ScriptLineNumber)]`r`n[Line Position: $($_.InvocationInfo.OffsetInLine)]`r`n[Code: $($_.InvocationInfo.Line.Trim())]`r`n"
        If ($ContinueOnError.IsPresent -eq $False) {Throw "$($ErrorMessage)"}
    }