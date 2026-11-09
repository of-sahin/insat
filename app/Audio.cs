using System;
using System.Runtime.InteropServices;

public static class EzanAudio {
    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    private class MMDeviceEnumerator { }

    [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IMMDeviceEnumerator {
        [PreserveSig] int EnumAudioEndpoints(int flow, int mask, out object devices);
        [PreserveSig] int GetDefaultAudioEndpoint(int flow, int role, out IMMDevice device);
    }
    [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IMMDevice {
        [PreserveSig] int Activate(ref Guid iid, int context, IntPtr args, [MarshalAs(UnmanagedType.IUnknown)] out object endpoint);
    }
    [ComImport, Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IAudioEndpointVolume {
        [PreserveSig] int RegisterControlChangeNotify(IntPtr notify);
        [PreserveSig] int UnregisterControlChangeNotify(IntPtr notify);
        [PreserveSig] int GetChannelCount(out uint count);
        [PreserveSig] int SetMasterVolumeLevel(float level, Guid context);
        [PreserveSig] int SetMasterVolumeLevelScalar(float level, Guid context);
        [PreserveSig] int GetMasterVolumeLevel(out float level);
        [PreserveSig] int GetMasterVolumeLevelScalar(out float level);
    }

    // Aynı ezan boyunca aynı cihazı tutar; varsayılan cihaz değişince başka cihazın sesini değiştirmez.
    private static IAudioEndpointVolume endpoint;
    public static float Begin() {
        End();
        IMMDeviceEnumerator enumerator = null;
        IMMDevice device = null;
        object audio = null;
        try {
            enumerator = (IMMDeviceEnumerator)new MMDeviceEnumerator();
            Marshal.ThrowExceptionForHR(enumerator.GetDefaultAudioEndpoint(0, 1, out device));
            Guid iid = typeof(IAudioEndpointVolume).GUID;
            Marshal.ThrowExceptionForHR(device.Activate(ref iid, 23, IntPtr.Zero, out audio));
            endpoint = (IAudioEndpointVolume)audio;
            float value;
            Marshal.ThrowExceptionForHR(endpoint.GetMasterVolumeLevelScalar(out value));
            return value;
        }
        catch { End(); throw; }
        finally {
            if (device != null) Marshal.ReleaseComObject(device);
            if (enumerator != null) Marshal.ReleaseComObject(enumerator);
        }
    }
    public static void Set(float value) {
        if (endpoint == null) throw new InvalidOperationException("Ses cihazı açılmadı.");
        Marshal.ThrowExceptionForHR(endpoint.SetMasterVolumeLevelScalar(Math.Max(0, Math.Min(1, value)), Guid.Empty));
    }
    public static void End() {
        if (endpoint != null) { Marshal.ReleaseComObject(endpoint); endpoint = null; }
    }
}
