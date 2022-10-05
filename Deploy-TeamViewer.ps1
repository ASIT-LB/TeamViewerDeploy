[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false)]
    [ValidateSet('Install','Uninstall','Repair')]
    [string]$DeploymentType = 'Install',
    [Parameter(Mandatory=$false)]
    [ValidateSet('Interactive','Silent','NonInteractive')]
    [string]$DeployMode = 'Interactive',
    [Parameter(Mandatory=$false)]
    [switch]$AllowRebootPassThru = $false,
    [Parameter(Mandatory=$false)]
    [switch]$TerminalServerMode = $false,
    [Parameter(Mandatory=$false)]
    [switch]$DisableLogging = $false
)

Try {
    ## Set the script execution policy for this process
    Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}

    ##*===============================================
    ##* VARIABLE DECLARATION
    ##*===============================================
    ## Variables: Application
    [string]$appVendor = ''
    [string]$appName = 'TeamViewer'
    [string]$appVersion = ''
    [string]$appArch = ''
    [string]$appLang = ''
    [string]$appRevision = ''
    [string]$appScriptVersion = '1.0.0'
    [string]$appScriptDate = '05/10/2022'
    [string]$appScriptAuthor = 'LB'
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    [string]$installName = ''
    [string]$installTitle = 'TeamViewer'

    ##* Do not modify section below
    #region DoNotModify

    ## Variables: Exit Code
    [int32]$mainExitCode = 0

    ## Variables: Script
    [string]$deployAppScriptFriendlyName = 'Deploy Application'
    [version]$deployAppScriptVersion = [version]'3.8.4'
    [string]$deployAppScriptDate = '26/01/2021'
    [hashtable]$deployAppScriptParameters = $psBoundParameters

    ## Variables: Environment
    If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
    [string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

    ## Dot source the required App Deploy Toolkit Functions
    Try {
        [string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
        If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
        If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
    }
    Catch {
        If ($mainExitCode -eq 0){ [int32]$mainExitCode = 60008 }
        Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
        ## Exit the script, returning the exit code to SCCM
        If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
    }

    #endregion
    ##* Do not modify section above
    ##*===============================================
    ##* END VARIABLE DECLARATION
    ##*===============================================

    If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
        ##*===============================================
        ##* PRE-INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Pre-Installation'

        ## Show Welcome Message, Close TeamViewer With a 60 Second Countdown Before Automatically Closing
        Show-InstallationWelcome -CloseApps 'TeamViewer' -CloseAppsCountdown 60

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## Remove Any Existing Versions of TeamViewer (MSI)
        Remove-MSIApplications "TeamViewer"

        ## Remove Any Existing Versions of TeamViewer (EXE)
        $AppList = Get-InstalledApplication -Name 'TeamViewer'
        
        ForEach ($App in $AppList)
        {
        If($App.UninstallString)
        {
        $UninstPath = $App.UninstallString -replace '"', ''
        
        If(Test-Path -Path $UninstPath)
        {
        Write-log -Message "Found $($App.DisplayName) ($($App.DisplayVersion)) and a valid uninstall string, now attempting to uninstall."

        Execute-Process -Path $UninstPath -Parameters '/S'
        Sleep -Seconds 5
        }
        }
        }
 
        ##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Installation'

        ## Install TeamViewer
        Show-InstallationProgress "Installing TeamViewer. This may take some time. Please wait..."
        Execute-Process -Path "$dirFiles\TeamViewer_Setup.exe" -Parameters "/S" -WindowStyle Hidden

        If ($ENV:PROCESSOR_ARCHITECTURE -eq 'x86'){
        Write-Log -Message "Detected 32-bit OS Architecture. Disabling TeamViewer Auto Update (32-bit Systems)" -Severity 1 -Source $deployAppScriptFriendlyName

        ## Disable TeamViewer Auto Update (32-bit Systems)
        Set-RegistryKey -Key 'HKLM\SOFTWARE\TeamViewer' -Name 'AutoUpdateMode' -Type DWord -Value '3'
        Set-RegistryKey -Key 'HKLM\SOFTWARE\TeamViewer' -Name 'UpdateCheckInterval' -Type DWord -Value '2'

        ## Restart TeamViewer Service
        Write-Log -Message "Restarting TeamViewer Service"
        Stop-ServiceAndDependencies -Name 'TeamViewer' -ErrorAction SilentlyContinue
        Start-ServiceAndDependencies -Name 'TeamViewer' -ErrorAction SilentlyContinue

        }
        Else
        {
        Write-Log -Message "Detected 64-bit OS Architecture. Disabling TeamViewer Auto Update (64-bit Systems)" -Severity 1 -Source $deployAppScriptFriendlyName
                
        ## Disable TeamViewer Auto Update (64-bit Systems)
        Set-RegistryKey -Key 'HKLM\SOFTWARE\WOW6432Node\TeamViewer' -Name 'AutoUpdateMode' -Type DWord -Value '3'
        Set-RegistryKey -Key 'HKLM\SOFTWARE\WOW6432Node\TeamViewer' -Name 'UpdateCheckInterval' -Type DWord -Value '2'

        ## Restart TeamViewer Service
        Write-Log -Message "Restarting TeamViewer Service"
        Stop-ServiceAndDependencies -Name 'TeamViewer' -ErrorAction SilentlyContinue
        Start-ServiceAndDependencies -Name 'TeamViewer' -ErrorAction SilentlyContinue
        }
       
        ##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Post-Installation'

    }
    ElseIf ($deploymentType -ieq 'Uninstall')
    {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        [string]$installPhase = 'Pre-Uninstallation'

        ## Show Welcome Message, Close TeamViewer With a 60 Second Countdown Before Automatically Closing
        Show-InstallationWelcome -CloseApps 'TeamViewer' -CloseAppsCountdown 60

        ## Show Progress Message (With a Message to Indicate the Application is Being Uninstalled)
        Show-InstallationProgress -StatusMessage "Uninstalling Application $installTitle. Please Wait..."

        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [string]$installPhase = 'Uninstallation'

        ## Remove Any Existing Versions of TeamViewer (MSI)
        Remove-MSIApplications "TeamViewer"

        ## Remove Any Existing Versions of TeamViewer (EXE)
        $AppList = Get-InstalledApplication -Name 'TeamViewer'
        
        ForEach ($App in $AppList)
        {
        If($App.UninstallString)
        {
        $UninstPath = $App.UninstallString -replace '"', ''
        
        If(Test-Path -Path $UninstPath)
        {
        Write-log -Message "Found $($App.DisplayName) ($($App.DisplayVersion)) and a valid uninstall string, now attempting to uninstall."

        Execute-Process -Path $UninstPath -Parameters '/S'
        Sleep -Seconds 5
        }
        }
        }

        ##*===============================================
        ##* POST-UNINSTALLATION
        ##*===============================================
        [string]$installPhase = 'Post-Uninstallation'


    }
    ElseIf ($deploymentType -ieq 'Repair')
    {
        ##*===============================================
        ##* PRE-REPAIR
        ##*===============================================
        [string]$installPhase = 'Pre-Repair'

        ## Show Progress Message (with the default message)
        Show-InstallationProgress


        ##*===============================================
        ##* REPAIR
        ##*===============================================
        [string]$installPhase = 'Repair'


        ##*===============================================
        ##* POST-REPAIR
        ##*===============================================
        [string]$installPhase = 'Post-Repair'


    }
    ##*===============================================
    ##* END SCRIPT BODY
    ##*===============================================

    ## Call the Exit-Script function to perform final cleanup operations
    Exit-Script -ExitCode $mainExitCode
}
Catch {
    [int32]$mainExitCode = 60001
    [string]$mainErrorMessage = "$(Resolve-Error)"
    Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
    Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
    Exit-Script -ExitCode $mainExitCode
}