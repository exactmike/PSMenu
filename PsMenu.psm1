###############################################################################################
#Module Variables and Variable Functions
###############################################################################################
function Get-PSMVariable
{
param
(
[string]$Name
)
    Get-Variable -Scope Script -Name $name 
}
function Get-PSMVariableValue
{
param
(
[string]$Name
)
    Get-Variable -Scope Script -Name $name -ValueOnly
}
function Set-PSMVariable
{
param
(
[string]$Name
,
$Value
)
    Set-Variable -Scope Script -Name $Name -Value $value  
}
function New-PSMVariable
{
param 
(
[string]$Name
,
$Value
)
    New-Variable -Scope Script -Name $name -Value $Value
}
function Remove-PSMVariable
{
param
(
[string]$Name
)
    Remove-Variable -Scope Script -Name $name
}
##########################################################################################################
#Core PSMenu Functions
##########################################################################################################
<#
    Script Module: PsMenu.psm1
    Author: Mike Campbell
    Version: 1.3
    Inspiration: @(
    http://stackoverflow.com/questions/24413295/powershell-console-menu-options-need-to-add-line-breaks
    https://gallery.technet.microsoft.com/scriptcenter/Powershell-Menu-a01643e2 #found this one only after I had developed PSMenu and begun deploying it.  
    http://www.zerrouki.com/powershell-menus-host-ui-promptforchoice-defined-or-dynamic/
    )
#>
function Get-MenuHierarchy {
<#
    .Synopsis
    Builds and returns a Menu Hierarchy for a given menu from an Menu Definitions Hashtable Object
    .DESCRIPTION
    Builds and returns a Menu Hierarchy for a given menu from an Menu Definitions Hashtable Object
    .EXAMPLE
    Primarily for use by other functions in PSMenu, this is the syntax that might be used:
    Get-MenuHierarchy -GUID $MenuDefinitions.'9e7ff8e1-afbb-418d-a31f-9c07bce3ab33'
    .INPUTS
    A Menu Definition Hashtable of Menu Definitions with Key being the menu GUID and value being teh menu Definitions
    .OUTPUTS
    String showing a representation of the menu hierarchy
#>
[cmdletbinding()]
param
(
    [parameter(Mandatory = $true)]
    $GUID
    ,
    $MenuDefinitions = $Script:MenuDefinitions
)
if (Test-Path -Path variable:Script:MenuDefinitions)
{
    $menuHierarchy = $MenuDefinitions.$GUID.Title
    $ParentGUID = $MenuDefinitions.$GUID.ParentGUID
    while ($ParentGUID)
    {
        $menuHierarchy = $($MenuDefinitions.$parentGUID.Title) + ' -> '  + $menuHierarchy
        $ParentGUID = $MenuDefinitions.$ParentGUID.ParentGUID    
    }#do
        $menuHierarchy
}#if
else
{
    Write-Verbose 'No Menu Definitions Exist from which to generate a hierarchy.'
}
}#function Get-MenuHierarchy
function Show-Menu {
<#
    .Synopsis
    Displays the User options from a menu defintion and returns user choice to the scriptblock which calls Show-Menu.
    .DESCRIPTION
    Displays the User options from a menu defintion and returns user choice to the scriptblock which calls Show-Menu. 
    Show-Menu is not usually called directly by a user, but instead becomes embedded in a scriptblock created by New-MenuScriptblock.
    .EXAMPLE
    Primarily for use by other functions in PSMenu, this is the syntax that might be used:
    Show-menu -MenuDefinition $MenuDefinition
    .INPUTS
    A Menu Definition Object
    .OUTPUTS
    Read-Host with custom Prompt
#>
[cmdletbinding()]
param
(
    $MenuDefinition
    ,
    [bool]$ClearHost
)
$childmenus = @(Get-ChildMenu -GUID $menudefinition.GUID)
$displaychoices = @()
$width = $(if ($host.Name -like '*ISE*') {$host.ui.RawUI.BufferSize.Width} else {$host.UI.RawUI.WindowSize.Width}) - 1
$num = 0
if ($menudefinition.Choices.Count -ge 1)
{
    foreach ($choice in $menudefinition.choices)
    {
        $num++
        $displaychoices += "$num $($choice.choice)"
    }#foreach
}#if
if ($childmenus.count -ge 1)
{
    foreach ($menu in $(Get-ChildMenu -GUID $menudefinition.GUID))
    {
        $num++
        $displaychoices += "$num $($menu.Title)"
    }#foreach
}#if
$displaychoicesstring = $displaychoices -join "`n`t"
#set menu title and Navigation Hierarcy
$menuTitle = $menudefinition.Title
$menuHierarchy = Get-MenuHierarchy -GUID $menudefinition.GUID
if ($menuHierarchy) {$menuprompt = "`nNavigation: $menuHierarchy"}
$menuprompt += @"

Current Menu: $menuTitle
$("=" * $width)

`t$displaychoicesstring

$("=" * $width)

"@
if ($menudefinition.ParentGUID)
{
    $menuprompt = $menuprompt + "`nEnter your selection or 'Q' to return to parent menu`n:"
}#if
else {$menuprompt = $menuprompt + "`nEnter your selection or 'Q' to exit this menu`n:"}
if ($MenuDefinition.ClearHost -or $ClearHost)
{
    if ($ClearHost)
    {
        Clear-Host
    }
}
read-host -Prompt $menuprompt
}#function Show-Menu
function New-MenuScriptBlock {
    <#
        .Synopsis
        Creates a scriptblock for execution by Invoke-Menu. 
        .DESCRIPTION
        Creates a scriptblock for execution by Invoke-Menu.  
        The scriptblock includes a scriptblock for display and capture of user choices and the scriptblocks for execution based on user choice selection. 
        .EXAMPLE
        Primarily for use by other functions in PSMenu, this is the syntax that might be used:
        New-MenuScriptBlock -MenuDefinition $MenuDefinition
        .INPUTS
        A Menu Definition Object
        .OUTPUTS
        A string, specifially a here-string, for conversion by Invoke-Menu to a scriptblock object.  
    #>
    [cmdletbinding()]
    param(
        $MenuDefinition
        ,
        [bool]$ClearHost
    )
    $num = 0
    $childmenus = @(Get-ChildMenu -GUID $menudefinition.GUID)
    $switchchoices = @(
        if ($menudefinition.choices.count -ge 1){
            foreach ($choice in $menudefinition.choices) {
                $num++
                "$num {$($choice.command)$(if ($choice.Exit){"`nSet-Variable -name Menu_exit -Value `$true -Scope Local"})}"
            }#foreach
        }#if
        if ($childmenus.count -ge 1) {
            foreach ($menu in $childmenus) {
                $num++
                "$num {$("Invoke-Menu -menuGUID $($menu.GUID)")}"
            }#foreach
        }#if
    )#switchchoices
    $switchchoicesstring = $switchchoices -join "`n`t`t"
    $commandstring = @"
Set-Variable -Name Menu_exit -Scope Local -Value `$false
do {
    `$selection = Show-Menu -MenuDefinition `$menudefinition -ClearHost `$ClearHost
    switch (`$Selection) {
        $($switchchoicesstring)
        'Q'{Set-Variable -Name Menu_exit -Scope Local -Value `$true}
        Default {
            Write-Host 'Invalid entry.  Please make another selection.'
        }
    }
    Start-Sleep -Milliseconds 1000
}#do
until (`$Local:Menu_exit)
"@
    if ($menudefinition.ClearHost -or $ClearHost)
    {
        if ($ClearHost)
        {$commandstring += "`nClear-Host"}
    }
    $commandstring 
}#Function New-MenuScriptBlock
function Invoke-Menu {
<#
    .Synopsis
    Invokes a scriptblock based on a MenuDefinition.  
    .DESCRIPTION
    Invokes a scriptblock based on a MenuDefinition.
    Calls New-MenuDefinition to create the scriptblock based on the MenuDefintion.  
    Executes the scriptblock (which has embedded in it the Show-Menu function for display and capture of user choices).
    .EXAMPLE
    Invoke-Menu -MenuDefinition $MenuDefinition
    Invokes a pre-created MenuDefinition Object.
    .EXAMPLE
    Invoke-Menu -MenuGUID 9e7ff8e1-afbb-418d-a31f-9c07bce3ab33
    Invokes a pre-created MenuDefinition Object which is stored in the Script:MenuDefinitions Hashtable
    .INPUTS
    A Menu Definition Object
    .OUTPUTS
    Invokes a scriptblock which is created based on the MenuDefinition Object
#>
[cmdletbinding()]
param
(
    [parameter(ParameterSetName='Definition')]
    $MenuDefinition
    ,
    [parameter(ParameterSetName='GUID')]
    $MenuGUID
    ,
    [bool]$ClearHost = $true
)
if ($PSCmdlet.ParameterSetName -eq 'GUID') {
    $MenuDefinition = $Script:MenuDefinitions.$menuGUID
}#if
if($menudefinition.Initialization) {
    $initialize = [scriptblock]::Create($menudefinition.Initialization)
    &$initialize
}#if
$scriptblock = [scriptblock]::Create($(New-MenuScriptBlock -menudefinition $menudefinition -ClearHost $ClearHost))
&$scriptblock
}#function Invoke-Menu
function Add-MenuDefinition {
[cmdletbinding()]
param
(
    $MenuDefinition
)
#create the Module Menu Definitions Hashtable if needed
if (Test-Path variable:Script:MenuDefinitions) {}
else {$Script:MenuDefinitions = @{}}
#add the new menu definition to the hashtable
$Script:MenuDefinitions.$($MenuDefinition.GUID)=$MenuDefinition
if ($MenuDefinition.ParentGUID) {Update-MenuChildLookup}
}#function Add-MenuDefinition
function Update-MenuChildLookup {
[cmdletbinding()]
param()
$Script:MenuChildLookup = @{}
$Script:MenuDefinitions.Values | Where-Object {$_.ParentGUID -ne $null} | foreach {$Script:MenuChildLookup.$($_.ParentGUID) += @($_.GUID)}
}#Function Add-ScriptMenuDefinition
function Get-ChildMenu {
[cmdletbinding()]
param
(
    [parameter(Mandatory = $true)]
    $GUID
)    
$ChildMenuGUIDs = @($Script:MenuChildLookup.$GUID | Sort-Object)
if ($ChildMenuGUIDs.count -ge 1) {
    $childMenus = @()
    foreach ($GUID in $ChildMenuGUIDs) {
        $childmenu = @{
            GUID = $GUID
            Title = $Script:MenuDefinitions.$GUID.Title
        }#childmenu
        $childMenus += $childmenu
    }#foreach
    $childMenus
}#if
}#function Get-ChildMenu
function New-DynamicMenuDefinition {
<#
    .Synopsis
    Creates a MenuDefinition Object dynamically for an array of string objects.  
    .DESCRIPTION
    Creates a MenuDefinition Object dynamically for an array of string objects.  
    .EXAMPLE
    $menudefinition = New-DynamicMenuDefinition -Title "Show properties of the selected file" -Choices (ls | select-object -expandproperty fullname) -command "Get-Item" -ChoiceAsCommandParameter 
    $menudefinition
    GUID           : 23348d70-2a4d-49b2-b9f3-40e6c8999c6e
    Title          : Show properties of the selected file
    Initialization : 
    Choices        : {@{choice=C:\test\document1.txt; command=Get-Item C:\test\document1.txt}, @{choice=C:\test\document3.txt; command=Get-Item C:\test\document3.txt}}
    ParentGUID     : 
    .INPUTS
    An array of strings to define the choices displayed.  A command to run.
    .OUTPUTS
    A MenuDefinition Object
#>
[cmdletbinding()]
param
(
    [string]$Title
    ,
    [string[]]$Choices
    ,
    [string]$command
    ,
    [string]$ParentMenu = $null
    ,
    $ParentGUID
    ,
    [switch]$ChoiceAsCommandParameter
    ,
    [string]$Initialization
)
if ($parentGUID) {}
else {$ParentGUID = $Script:MenuDefinitions | Where-Object Title -eq $ParentMenu | Select-Object -ExpandProperty GUID}
    
$menudefinition = [pscustomobject]@{
    GUID = [guid]::NewGuid().Guid
    Title = $Title
    Initialization = $Initialization
    Choices = @(
        foreach ($choice in $choices) {
            switch ($ChoiceAsCommandParameter) {
                $true {[pscustomobject]@{choice="$choice";command="$command $choice"}}
                Default {[pscustomobject]@{choice="$choice";command="$command"}}
            }#switch
        }
    )
    ParentGUID = $ParentGUID
}#$menudefinition
$menudefinition
}
function Read-DynamicMenu {
<#
    .Synopsis
    Creates a MenuDefinition Object dynamically for an array of string objects.  
    .DESCRIPTION
    Creates a MenuDefinition Object dynamically for an array of string objects.  
    .EXAMPLE
    $menudefinition = New-DynamicMenuDefinition -Title "Show properties of the selected file" -Choices (ls | select-object -expandproperty fullname) -command "Get-Item" -ChoiceAsCommandParameter 
    $menudefinition
    GUID           : 23348d70-2a4d-49b2-b9f3-40e6c8999c6e
    Title          : Show properties of the selected file
    Initialization : 
    Choices        : {@{choice=C:\test\document1.txt; command=Get-Item C:\test\document1.txt}, @{choice=C:\test\document3.txt; command=Get-Item C:\test\document3.txt}}
    ParentGUID     : 
    .INPUTS
    An array of strings to define the choices displayed.  A command to run.
    .OUTPUTS
    A MenuDefinition Object
#>
[cmdletbinding()]
param
(
    [string]$Title
    ,
    [string[]]$Choices
    ,
    [string]$ParentMenu = $null
    ,
    $ParentGUID
    ,
    [string]$Initialization
    ,
    [bool]$ClearHost = $true
)
if ($parentGUID) {}
else {$ParentGUID = $Script:MenuDefinitions | Where-Object Title -eq $ParentMenu | Select-Object -ExpandProperty GUID}
$menudefinition = [pscustomobject]@{
    GUID = [guid]::NewGuid().Guid
    Title = $Title
    Initialization = $Initialization
    ClearHost = $ClearHost
    Choices = @(
        foreach ($choice in $choices)
        {
            [pscustomobject]@{choice="$choice";command="Write-Output $choice";exit=$true}
        }
    )
    ParentGUID = $ParentGUID
}#$menudefinition
Invoke-Menu -MenuDefinition $menudefinition -ClearHost $ClearHost
}