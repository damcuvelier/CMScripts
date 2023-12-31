function Add2log($loginfo){
$erroractionpreference = 'silentlycontinue'
Set-ExecutionPolicy -ExecutionPolicy bypass -force
$here = $PSScriptRoot; if(!$here){$here = (Get-Location).path}
	$loginfo | out-file "$here\DelCMDrivers.log" -Append -Encoding ascii -Force
}


function connCM{
$erroractionpreference = 'silentlycontinue'
Set-ExecutionPolicy -ExecutionPolicy bypass -force
$here = $PSScriptRoot; if(!$here){$here = (Get-Location).path}
$COMPUTERNAME = $env:COMPUTERNAME
$USERDOMAIN = $env:USERDOMAIN
if($COMPUTERNAME -eq $USERDOMAIN){$MPFQDN = $COMPUTERNAME}else{$MPFQDN = "$COMPUTERNAME.$USERDOMAIN"}
Import-Module ($Env:SMS_ADMIN_UI_PATH.Substring(0,$Env:SMS_ADMIN_UI_PATH.Length-5) + '\ConfigurationManager.psd1')
New-PSDrive -Name $SiteName -PSProvider "AdminUI.PS.Provider\CMSite" -Root $MPFQDN -Description "SCCM Site"
$CMDrive = $SiteName + ':'
return $CMDrive
}



function delcatMod{
param($Name)
$erroractionpreference = 'silentlycontinue'
Set-ExecutionPolicy -ExecutionPolicy bypass -force
$here = $PSScriptRoot; if(!$here){$here = (Get-Location).path}
$Categorie = Get-CMDriverPackageCategory | Where-Object { $_.Name -match $Name }
if ($Categorie -ne $null) {Remove-CMDriverPackageCategory -CategoryId $Categorie.CategoryId}
else{return 'N/A'}
}


function GetMatchDrvs{
param($ModelName,$ModelPkgDrv)
$erroractionpreference = 'silentlycontinue'
Set-ExecutionPolicy -ExecutionPolicy bypass -force
$here = $PSScriptRoot; if(!$here){$here = (Get-Location).path}

$DriverPackage = Get-CMDriverPackage | Where-Object { $_.Name -like "*$ModelPkgDrv*" }
if ($DriverPackage -ne $null) {
    $DriversInPackage = Get-CMDriverPackageDriver | Where-Object { $_.PackageID -eq $DriverPackage.PackageID }
    $MatchingDrivers += $DriversInPackage | ForEach-Object {
        $Driver = Get-CMDriver -DriverID $_.DriverID
        if ($Driver.Content -like "*$ModelName*") {$Driver}
    }
	if(!$MatchingDrivers){$MatchingDrivers = 'N/A'}
return $MatchingDrivers
}

}

function GetOnlyMatchDrvs{
param($ModelName)
$erroractionpreference = 'silentlycontinue'
Set-ExecutionPolicy -ExecutionPolicy bypass -force
$here = $PSScriptRoot; if(!$here){$here = (Get-Location).path}
$ModelPkgDrv = $ModelName.replace(' ','_')
$MatchDrvs = GetMatchDrvs -ModelName $ModelName -ModelPkgDrv $ModelPkgDrv
if($MatchDrvs -eq 'N/A'){Add2log "GetMatchDrvs: $ModelName Unknown"}

$OtherDriverPackages = Get-CMDriverPackage | Where-Object { $_.Name -notlike "*$ModelPkgDrv*" }
$UniqueDrivers = @()
foreach ($Driver in $MatchDrvs.split(';')) {
    $IsUnique = $true

    foreach ($OtherPackage in $OtherDriverPackages) {
        $DriversInOtherPackage = Get-CMDriverPackageDriver | Where-Object { $_.PackageID -eq $OtherPackage.PackageID }
        if ($DriversInOtherPackage -contains $Driver) {
            $IsUnique = $false
            break
        }
    }

if ($IsUnique) {$UniqueDrivers += $Driver}
}

$UniqueDrivers
}

function DelCMDrivers{
param($ModelName,$OSR,$OSV,[switch]$tst)
$erroractionpreference = 'silentlycontinue'
Set-ExecutionPolicy -ExecutionPolicy bypass -force
$here = $PSScriptRoot; if(!$here){$here = (Get-Location).path}



if($OSR){
	if($OSV){$ModelName = "$ModelName-$OSR-$OSV"}else{$ModelName = "$ModelName-$OSR"}
}


if($tst){
	Write-Host "fct:DelCMDrivers"
	pause
}

$CMDrive = connCM
$ModelCat = $ModelName.replace(' ','_')
$deleteCategory = delcatMod -Name $ModelCat
if($deleteCategory -ne 'N/A'){
	$Drivers2Del = Get-CMDriver | Where-Object { $_.Category -eq $null }
}else{
	$Drivers2Del = GetOnlyMatchDrvs -ModelName $ModelName
}

foreach ($Driver in $Drivers2Del) {
	Remove-CMDriver -DriverId $Driver.DriverId -Force
	Add2log "Suppression du pilote $($Driver.LocalizedDisplayName) pour le model $ModelName"
}

}