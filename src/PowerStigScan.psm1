Import-Module PowerStig -RequiredVersion 3.1.0

. $PsScriptRoot\Common\helpers.ps1
. $PsScriptRoot\Common\PowerStigScan.Computer.ps1
. $PsScriptRoot\Common\PowerStigScan.Config.ps1
. $PsScriptRoot\Common\PowerStigScan.Results.ps1
. $PsScriptRoot\Common\PowerStigScan.Scap.ps1
. $PsScriptRoot\Common\PowerStigScan.Main.ps1

Export-ModuleMember -Function @('Invoke-PowerStigScan','Add-PowerStigComputer','Get-PowerStigSqlConfig','Set-PowerStigSqlConfig',
                                'Get-PowerStigConfig','Get-PowerStigComputer','Set-PowerStigComputer',
                                'Remove-PowerStigComputer','Get-PowerStigOrgSettings','Start-PowerStigDSCScan')