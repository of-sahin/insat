# --- CONFIGURATION (AYARLAR) ---
$Sehir = "Istanbul"  # Hangi şehirdeyseniz İngilizce karakterlerle yazın (Örn: Ankara, Izmir, Bursa)
$EzanSaatleri = @(
    "05:30", # Sabah
    "13:00", # Öğle
    "16:30", # İkindi
    "22:08", # Akşam
    "21:15"  # Yatsı
)
$MuteDurationSeconds = 480
$FadeDurationSeconds = 60
# -------------------------------

if (-not ([System.Management.Automation.PSTypeName]'AudioManagerEzan').Type) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public class AudioManagerEzan {
    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    private class MMDeviceEnumerator { }

    [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IMMDeviceEnumerator {
        int EnumAudioEndpoints(int dataFlow, int stateMask, out object devices);
        int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice device);
    }

    [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IMMDevice {
        int Activate(ref Guid iid, int clsCtx, IntPtr activationParams, [MarshalAs(UnmanagedType.IUnknown)] out object interfacePointer);
    }

    [ComImport, Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IAudioEndpointVolume {
        int RegisterControlChangeNotify(IntPtr notify);
        int UnregisterControlChangeNotify(IntPtr notify);
        int GetChannelCount(out uint channelCount);
        int SetMasterVolumeLevel(float level, Guid context);
        int SetMasterVolumeLevelScalar(float level, Guid context);
        int GetMasterVolumeLevel(out float level);
        int GetMasterVolumeLevelScalar(out float level);
    }

    private static IAudioEndpointVolume GetEndpointVolume() {
        var enumerator = (IMMDeviceEnumerator)new MMDeviceEnumerator();
        IMMDevice device;
        Marshal.ThrowExceptionForHR(enumerator.GetDefaultAudioEndpoint(0, 1, out device));
        var iid = typeof(IAudioEndpointVolume).GUID;
        object endpoint;
        Marshal.ThrowExceptionForHR(device.Activate(ref iid, 23, IntPtr.Zero, out endpoint));
        return (IAudioEndpointVolume)endpoint;
    }

    public static float GetVolume() {
        float volume;
        Marshal.ThrowExceptionForHR(GetEndpointVolume().GetMasterVolumeLevelScalar(out volume));
        return volume;
    }

    public static void SetVolume(float volume) {
        Marshal.ThrowExceptionForHR(GetEndpointVolume().SetMasterVolumeLevelScalar(volume, Guid.Empty));
    }
}
'@
}

function Write-Log {
    param ([string]$Message)
    Write-Host ("[{0}] {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $Message)
}

function Set-VolumeSmoothly {
    param ([float]$StartVolume, [float]$EndVolume, [int]$DurationSecs)
    $VolumeDifference = [Math]::Abs($EndVolume - $StartVolume)
    $Steps = [Math]::Max(1, [int][Math]::Round(($VolumeDifference * 100), 0))
    $VolumeStep = ($EndVolume - $StartVolume) / $Steps
    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    for ($i = 1; $i -le $Steps; $i++) {
        $Volume = [float]($StartVolume + ($VolumeStep * $i))
        $Volume = [Math]::Max(0.0, [Math]::Min(1.0, $Volume))
        [AudioManagerEzan]::SetVolume($Volume)
        Write-Log ("Adım {0}/{1} - Ses seviyesi: {2}%" -f $i, $Steps, ($Volume * 100).ToString("0.0"))
        $TargetMilliseconds = ($DurationSecs * 1000 * $i) / $Steps
        $RemainingMilliseconds = [int]($TargetMilliseconds - $Stopwatch.Elapsed.TotalMilliseconds)
        if ($RemainingMilliseconds -gt 0) {
            Start-Sleep -Milliseconds $RemainingMilliseconds
        }
    }
    $Stopwatch.Stop()
}

$TriggerTimes = $EzanSaatleri

Write-Log "Ezan Saati Takip Programı Başlatıldı ($Sehir)..."
if ($TriggerTimes) { Write-Log "Ezan Vakitleri: $TriggerTimes" }

while ($true) {
    $Now = Get-Date
    $CurrentTime = $Now.ToString("HH:mm")

    # Eğer şu anki saat ezan vakitlerinden biriyse tetikle
    if ($TriggerTimes -and ($TriggerTimes -contains $CurrentTime)) {
        Write-Log "Ezan vakti geldi ($CurrentTime). Ses yavaşça kısılıyor..."
        $OriginalVolume = [AudioManagerEzan]::GetVolume()
        Set-VolumeSmoothly -StartVolume $OriginalVolume -EndVolume 0 -DurationSecs $FadeDurationSeconds
        
        $WaitTimeSecs = $MuteDurationSeconds - ($FadeDurationSeconds * 2)
        if ($WaitTimeSecs -gt 0) { Start-Sleep -Seconds $WaitTimeSecs }

        Write-Log "Ezan bitti. Ses yavaşça eski haline getiriliyor..."
        Set-VolumeSmoothly -StartVolume 0 -EndVolume $OriginalVolume -DurationSecs $FadeDurationSeconds
        
        Start-Sleep -Seconds 61
    }

    Start-Sleep -Seconds 1
}