function Initialize-InsatLocation {
    if (-not ('InsatGeoDatabase' -as [type])) {
        Add-Type -AssemblyName System.Device
        Add-Type -AssemblyName System.Web.Extensions
        Add-Type -Path (Join-Path $PSScriptRoot 'Location.cs') -ReferencedAssemblies @('System.dll', 'System.Device.dll', 'System.Web.Extensions.dll')
    }
}

function Resolve-InsatLocation {
    param ([string]$Province, [string]$District, [hashtable]$Locations)
    $Key = ConvertTo-LocationKey $Province
    if ($Key -eq 'ICEL') { $Key = 'MERSIN' }
    if ($Key -eq 'AFYON') { $Key = 'AFYONKARAHISAR' }
    $Cities = @($Locations.Keys | Where-Object { (ConvertTo-LocationKey $_) -eq $Key })
    if ($Cities.Count -ne 1) { throw 'Bulunan il vakit listesinde yok. İl ve ilçeyi elle seçebilirsin.' }
    $City = $Cities[0]
    $DistrictKey = ConvertTo-LocationKey $District
    $Matches = @($Locations[$City] | Where-Object { (ConvertTo-LocationKey $_) -eq $DistrictKey })
    if ($Matches.Count -eq 1) {
        return [pscustomobject]@{ City = $City; District = $Matches[0]; IsCentralFallback = $false; DetectedDistrict = $District }
    }
    $Central = @($Locations[$City] | Where-Object { (ConvertTo-LocationKey $_) -eq (ConvertTo-LocationKey $City) })
    if ($Central.Count -ne 1) { throw "Bulunan $Province / $District için uygun vakit bölgesi bulunamadı. İlçeyi elle seçebilirsin." }
    [pscustomobject]@{ City = $City; District = $Central[0]; IsCentralFallback = $true; DetectedDistrict = $District }
}
