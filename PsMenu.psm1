##########################################################################################################
#Menu Functions
##########################################################################################################
function Get-MenuHierarchy {
param(
$GUID
)
$menuHierarchy = $Global:MenuDefinitions.$GUID.Title
$ParentGUID = $Global:MenuDefinitions.$GUID.ParentGUID
while ($ParentGUID){
    $menuHierarchy = $($Global:MenuDefinitions.$parentGUID.Title) + ' -> '  + $menuHierarchy
    $ParentGUID = $Global:MenuDefinitions.$ParentGUID.ParentGUID    
}#do
Return $menuHierarchy
}
function Show-Menu {
param(
$menudefinition
)

$childmenus = @(Get-ChildMenu -GUID $menudefinition.GUID)
$displaychoices = @()

$num = 0
if ($menudefinition.Choices.Count -ge 1) {
    foreach ($choice in $menudefinition.choices) {
        $num++
        $displaychoices += "$num $($choice.choice)"
    }#foreach
}#if
if ($childmenus.count -ge 1) {
    foreach ($menu in $(Get-ChildMenu -GUID $menudefinition.GUID)) {
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
======================================================================================================================

`t$displaychoicesstring

======================================================================================================================

"@
if ($menudefinition.ParentGUID) {
    $menuprompt = $menuprompt + "`nEnter your selection or 'Q' to return to parent menu`n:"
}
else {$menuprompt = $menuprompt + "`nEnter your selection or 'Q' to exit this menu`n:"}

clear-host
read-host -Prompt $menuprompt

}
function New-MenuScriptBlock {
param(
$menudefinition
)
$num = 0
$childmenus = @(Get-ChildMenu -GUID $menudefinition.GUID)
$switchchoices = @(
    if ($menudefinition.choices.count -ge 1){
        foreach ($choice in $menudefinition.choices) {
            $num++
            "$num {$($choice.command)}"
        }#foreach
    }#if
    if ($childmenus.count -ge 1) {
        foreach ($menu in $childmenus) {
            $num++
            "$num {$("Invoke-Menu -menuGUID $($menu.GUID)")}"
        }#foreach
    }#if
)
$switchchoicesstring = $switchchoices -join "`n`t`t"
$commandstring = @"
`$exit = `$false
do {
    `$selection = Show-Menu -MenuDefinition `$menudefinition
    switch (`$Selection) {
        $($switchchoicesstring)
        'Q'{`$exit = `$true}
        Default {
            Write-Host 'Invalid entry.  Please make another selection.'
        }
    }
    Start-Sleep -Milliseconds 500
}#do
until (`$exit)
Clear-Host
"@

$commandstring
}
function Invoke-Menu {
param(
[parameter(ParameterSetName='Definition')]
$menudefinition
,
[parameter(ParameterSetName='GUID')]
$menuGUID
)
if ($PSCmdlet.ParameterSetName -eq 'GUID') {
$menudefinition = $Global:MenuDefinitions.$menuGUID
}
if($menudefinition.Initialization) {
    $initialize = [scriptblock]::Create($menudefinition.Initialization)
    &$initialize
}
$scriptblock = [scriptblock]::Create($(New-MenuScriptBlock -menudefinition $menudefinition))
&$scriptblock
}
function Add-GlobalMenuDefinition {
param(
$MenuDefinition
)
#create the Global Menu Definitions Hashtable if needed
if (Test-Path variable:Global:MenuDefinitions) {}
else {$Global:MenuDefinitions = @{}}
#add the new menu definition to the hashtable
$Global:MenuDefinitions.$($MenuDefinition.GUID)=$MenuDefinition
if ($MenuDefinition.ParentGUID) {Update-MenuChildLookup}
}
function Update-MenuChildLookup {
    $Global:MenuChildLookup = @{}
    $global:MenuDefinitions.Values | Where-Object {$_.ParentGUID -ne $null} | foreach {$Global:MenuChildLookup.$($_.ParentGUID) += @($_.GUID)}
}
function Get-ChildMenu {
param(
$GUID
)    
$ChildMenuGUIDs = @($Global:MenuChildLookup.$GUID | Sort-Object)
if ($ChildMenuGUIDs.count -ge 1) {
    $childMenus = @()
    foreach ($GUID in $ChildMenuGUIDs) {
        $childmenu = @{
            GUID = $GUID
            Title = $Global:MenuDefinitions.$GUID.Title
        }#childmenu
        $childMenus += $childmenu
    }
    Return $childMenus
}
}
function New-DynamicMenuDefinition {
param(
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
else {$ParentGUID = $Global:MenuDefinitions | Where-Object Title -eq $ParentMenu | Select-Object -ExpandProperty GUID}
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
}
Return $menudefinition
}