Clear-Host
Import-Module PSMenu -Force
$menudefinition = [pscustomobject]@{
                    GUID = '94301e0f-50f3-4af5-bee8-989753feb9a1'
                    Title = 'Test'
                    Initialization = $Null
                    Choices = @(
                        [pscustomobject]@{choice='this is choice 1';command='Write-Host -Object "This was Choice 1" -ForegroundColor Green';exit=$false}
                        [pscustomobject]@{choice='this is choice 2 with Exit';command='Write-Host -Object "This was Choice 2" -ForegroundColor Red';exit=$true}                        
                        [pscustomobject]@{choice='this is choice 3';command='Write-Host -Object "This was Choice 3" -ForegroundColor Yellow';exit=$false}                        
                    )
                    ParentGUID = $Null
                }

Invoke-Menu -MenuDefinition $menudefinition