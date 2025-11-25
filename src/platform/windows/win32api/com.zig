const std = @import("std");
const win32 = std.os.windows;

const HRESULT = win32.HRESULT;
const GUID = win32.GUID;

//--------------
// General
//--------------
pub const IUnknown = extern union {
    pub const VTable = extern struct {
        QueryInterface: *const fn (
            self: *const IUnknown,
            riid: *const win32.GUID,
            ppvObject: **anyopaque,
        ) callconv(.winapi) win32.HRESULT,
        AddRef: *const fn (
            self: *const IUnknown,
        ) callconv(.winapi) u32,
        Release: *const fn (
            self: *const IUnknown,
        ) callconv(.winapi) u32,
    };
    vtable: *const VTable,
    pub inline fn QueryInterface(
        self: *const IUnknown,
        riid: *const win32.GUID,
        ppvObject: **anyopaque,
    ) win32.HRESULT {
        return self.vtable.QueryInterface(self, riid, ppvObject);
    }
    pub inline fn AddRef(self: *const IUnknown) u32 {
        return self.vtable.AddRef(self);
    }
    pub inline fn Release(self: *const IUnknown) u32 {
        return self.vtable.Release(self);
    }
};

//-------------
// Audio
//-------------
pub const AUDCLNT_SHAREMODE = enum(i32) {
    SHARED = 0,
    EXCLUSIVE = 1,
};
pub const AUDCLNT_SHAREMODE_SHARED = AUDCLNT_SHAREMODE.SHARED;
pub const AUDCLNT_SHAREMODE_EXCLUSIVE = AUDCLNT_SHAREMODE.EXCLUSIVE;

pub const AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM = 0x80000000;
pub const AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY = 0x08000000;
pub const AUDCLNT_STREAMFLAGS_EVENTCALLBACK = 0x00040000;

pub const WAVEFORMATEX = extern struct {
    wFormatTag: u16 align(1),
    nChannels: u16 align(1),
    nSamplesPerSec: u32 align(1),
    nAvgBytesPerSec: u32 align(1),
    nBlockAlign: u16 align(1),
    wBitsPerSample: u16 align(1),
    cbSize: u16 align(1),
};
pub const WAVE_FORMAT_PCM = 0x0001;
pub const WAVE_FORMAT_EXTENSIBLE = 0xfffe;

pub const WAVEFORMATEXTENSIBLE = extern struct {
    Format: WAVEFORMATEX align(1),
    Samples: extern union {
        wValidBitsPerSample: u16 align(1),
        wSamplesPerBlock: u16 align(1),
        wReserved: u16 align(1),
    } align(1),
    dwChannelMask: u32 align(1),
    SubFormat: GUID align(1),
};
pub const SPEAKER_FRONT_LEFT = 0x00000001;
pub const SPEAKER_FRONT_RIGHT = 0x00000002;
pub const SPEAKER_FRONT_CENTER = 0x00000004;

pub const EDataFlow = enum(i32) {
    eRender = 0,
    eCapture = 1,
    eAll = 2,
    EDataFlow_enum_count = 3,
};

pub const ERole = enum(i32) {
    eConsole = 0,
    eMultimedia = 1,
    eCommunications = 2,
    ERole_enum_count = 3,
};

pub const PROPERTYKEY = extern struct {
    fmtid: GUID,
    pid: u32,
};

const IID_IMMDevice_Value = GUID.parse("{d666063f-1587-4e43-81f1-b948e807363f}");
pub const IID_IMMDevice = &IID_IMMDevice_Value;
pub const IMMDevice = extern union {
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        Activate: *const fn (
            self: *const IMMDevice,
            iid: ?*const GUID,
            dwClsCtx: win32.DWORD,
            pActivationParams: ?*anyopaque, //NOTE: normaly PROPVARIANT but we are passing null eitherway
            ppInterface: **anyopaque,
        ) callconv(.winapi) HRESULT,
        OpenPropertyStore: *anyopaque, //NOTE: unused function
        GetId: *const fn (
            self: *const IMMDevice,
            ppstrId: ?*?win32.PWSTR,
        ) callconv(.winapi) HRESULT,
        GetState: *const fn (
            self: *const IMMDevice,
            pdwState: ?*u32,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    IUnknown: IUnknown,
    pub inline fn Activate(self: *const IMMDevice, iid: ?*const GUID, dwClsCtx: win32.DWORD, pActivationParams: ?*anyopaque, ppInterface: **anyopaque) HRESULT {
        return self.vtable.Activate(self, iid, dwClsCtx, pActivationParams, ppInterface);
    }
    pub inline fn GetId(self: *const IMMDevice, ppstrId: ?*?win32.PWSTR) HRESULT {
        return self.vtable.GetId(self, ppstrId);
    }
    pub inline fn GetState(self: *const IMMDevice, pdwState: ?*u32) HRESULT {
        return self.vtable.GetState(self, pdwState);
    }
};

const IID_IMMNotificationClient_Value = GUID.initString("7991eec9-7e89-4d85-8390-6c703cec60c0");
pub const IID_IMMNotificationClient = &IID_IMMNotificationClient_Value;
pub const IMMNotificationClient = extern union {
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        OnDeviceStateChanged: *const fn (
            self: *const IMMNotificationClient,
            pwstrDeviceId: ?[*:0]const u16,
            dwNewState: u32,
        ) callconv(.winapi) HRESULT,
        OnDeviceAdded: *const fn (
            self: *const IMMNotificationClient,
            pwstrDeviceId: ?[*:0]const u16,
        ) callconv(.winapi) HRESULT,
        OnDeviceRemoved: *const fn (
            self: *const IMMNotificationClient,
            pwstrDeviceId: ?[*:0]const u16,
        ) callconv(.winapi) HRESULT,
        OnDefaultDeviceChanged: *const fn (
            self: *const IMMNotificationClient,
            flow: EDataFlow,
            role: ERole,
            pwstrDefaultDeviceId: ?[*:0]const u16,
        ) callconv(.winapi) HRESULT,
        OnPropertyValueChanged: *const fn (
            self: *const IMMNotificationClient,
            pwstrDeviceId: ?[*:0]const u16,
            key: PROPERTYKEY,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    IUnknown: IUnknown,
    pub inline fn OnDeviceStateChanged(self: *const IMMNotificationClient, pwstrDeviceId: ?[*:0]const u16, dwNewState: u32) HRESULT {
        return self.vtable.OnDeviceStateChanged(self, pwstrDeviceId, dwNewState);
    }
    pub inline fn OnDeviceAdded(self: *const IMMNotificationClient, pwstrDeviceId: ?[*:0]const u16) HRESULT {
        return self.vtable.OnDeviceAdded(self, pwstrDeviceId);
    }
    pub inline fn OnDeviceRemoved(self: *const IMMNotificationClient, pwstrDeviceId: ?[*:0]const u16) HRESULT {
        return self.vtable.OnDeviceRemoved(self, pwstrDeviceId);
    }
    pub inline fn OnDefaultDeviceChanged(self: *const IMMNotificationClient, flow: EDataFlow, role: ERole, pwstrDefaultDeviceId: ?[*:0]const u16) HRESULT {
        return self.vtable.OnDefaultDeviceChanged(self, flow, role, pwstrDefaultDeviceId);
    }
    pub inline fn OnPropertyValueChanged(self: *const IMMNotificationClient, pwstrDeviceId: ?[*:0]const u16, key: PROPERTYKEY) HRESULT {
        return self.vtable.OnPropertyValueChanged(self, pwstrDeviceId, key);
    }
};

const IID_IMMDeviceCollection_Value = GUID.parse("{0bd7a1be-7a1a-44db-8397-cc5392387b5e}");
pub const IID_IMMDeviceCollection = &IID_IMMDeviceCollection_Value;
pub const IMMDeviceCollection = extern union {
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        GetCount: *const fn (
            self: *const IMMDeviceCollection,
            pcDevices: ?*u32,
        ) callconv(.winapi) HRESULT,
        Item: *const fn (
            self: *const IMMDeviceCollection,
            nDevice: u32,
            ppDevice: ?*?*IMMDevice,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    IUnknown: IUnknown,
    pub inline fn GetCount(self: *const IMMDeviceCollection, pcDevices: ?*u32) HRESULT {
        return self.vtable.GetCount(self, pcDevices);
    }
    pub inline fn Item(self: *const IMMDeviceCollection, nDevice: u32, ppDevice: ?*?*IMMDevice) HRESULT {
        return self.vtable.Item(self, nDevice, ppDevice);
    }
};

const CLSID_MMDeviceEnumerator_Value = GUID.parse("{bcde0395-e52f-467c-8e3d-c4579291692e}");
pub const CLSID_MMDeviceEnumerator = &CLSID_MMDeviceEnumerator_Value;

const IID_IMMDeviceEnumerator_Value = GUID.parse("{a95664d2-9614-4f35-a746-de8db63617e6}");
pub const IID_IMMDeviceEnumerator = &IID_IMMDeviceEnumerator_Value;
pub const IMMDeviceEnumerator = extern union {
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        EnumAudioEndpoints: *const fn (
            self: *const IMMDeviceEnumerator,
            dataFlow: EDataFlow,
            dwStateMask: u32,
            ppDevices: ?*?*IMMDeviceCollection,
        ) callconv(.winapi) HRESULT,
        GetDefaultAudioEndpoint: *const fn (
            self: *const IMMDeviceEnumerator,
            dataFlow: EDataFlow,
            role: ERole,
            ppEndpoint: ?*?*IMMDevice,
        ) callconv(.winapi) HRESULT,
        GetDevice: *const fn (
            self: *const IMMDeviceEnumerator,
            pwstrId: ?[*:0]const u16,
            ppDevice: ?*?*IMMDevice,
        ) callconv(.winapi) HRESULT,
        RegisterEndpointNotificationCallback: *const fn (
            self: *const IMMDeviceEnumerator,
            pClient: ?*IMMNotificationClient,
        ) callconv(.winapi) HRESULT,
        UnregisterEndpointNotificationCallback: *const fn (
            self: *const IMMDeviceEnumerator,
            pClient: ?*IMMNotificationClient,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    IUnknown: IUnknown,
    pub inline fn EnumAudioEndpoints(self: *const IMMDeviceEnumerator, dataFlow: EDataFlow, dwStateMask: u32, ppDevices: ?*?*IMMDeviceCollection) HRESULT {
        return self.vtable.EnumAudioEndpoints(self, dataFlow, dwStateMask, ppDevices);
    }
    pub inline fn GetDefaultAudioEndpoint(self: *const IMMDeviceEnumerator, dataFlow: EDataFlow, role: ERole, ppEndpoint: ?*?*IMMDevice) HRESULT {
        return self.vtable.GetDefaultAudioEndpoint(self, dataFlow, role, ppEndpoint);
    }
    pub inline fn GetDevice(self: *const IMMDeviceEnumerator, pwstrId: ?[*:0]const u16, ppDevice: ?*?*IMMDevice) HRESULT {
        return self.vtable.GetDevice(self, pwstrId, ppDevice);
    }
    pub inline fn RegisterEndpointNotificationCallback(self: *const IMMDeviceEnumerator, pClient: ?*IMMNotificationClient) HRESULT {
        return self.vtable.RegisterEndpointNotificationCallback(self, pClient);
    }
    pub inline fn UnregisterEndpointNotificationCallback(self: *const IMMDeviceEnumerator, pClient: ?*IMMNotificationClient) HRESULT {
        return self.vtable.UnregisterEndpointNotificationCallback(self, pClient);
    }
};
const IID_IAudioClient_Value = win32.GUID.parse("{1cb9ad4c-dbfa-4c32-b178-c2f568a703b2}");
pub const IID_IAudioClient = &IID_IAudioClient_Value;
pub const IAudioClient = extern union {
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        Initialize: *const fn (
            self: *const IAudioClient,
            ShareMode: AUDCLNT_SHAREMODE,
            StreamFlags: u32,
            hnsBufferDuration: i64,
            hnsPeriodicity: i64,
            pFormat: ?*const WAVEFORMATEX,
            AudioSessionGuid: ?*const win32.GUID,
        ) callconv(.winapi) win32.HRESULT,
        GetBufferSize: *const fn (
            self: *const IAudioClient,
            pNumBufferFrames: ?*u32,
        ) callconv(.winapi) win32.HRESULT,
        GetStreamLatency: *const fn (
            self: *const IAudioClient,
            phnsLatency: ?*i64,
        ) callconv(.winapi) win32.HRESULT,
        GetCurrentPadding: *const fn (
            self: *const IAudioClient,
            pNumPaddingFrames: ?*u32,
        ) callconv(.winapi) win32.HRESULT,
        IsFormatSupported: *const fn (
            self: *const IAudioClient,
            ShareMode: AUDCLNT_SHAREMODE,
            pFormat: ?*const WAVEFORMATEX,
            ppClosestMatch: ?*?*WAVEFORMATEX,
        ) callconv(.winapi) win32.HRESULT,
        GetMixFormat: *const fn (
            self: *const IAudioClient,
            ppDeviceFormat: ?*?*WAVEFORMATEX,
        ) callconv(.winapi) win32.HRESULT,
        GetDevicePeriod: *const fn (
            self: *const IAudioClient,
            phnsDefaultDevicePeriod: ?*i64,
            phnsMinimumDevicePeriod: ?*i64,
        ) callconv(.winapi) win32.HRESULT,
        Start: *const fn (
            self: *const IAudioClient,
        ) callconv(.winapi) win32.HRESULT,
        Stop: *const fn (
            self: *const IAudioClient,
        ) callconv(.winapi) win32.HRESULT,
        Reset: *const fn (
            self: *const IAudioClient,
        ) callconv(.winapi) win32.HRESULT,
        SetEventHandle: *const fn (
            self: *const IAudioClient,
            eventHandle: ?win32.HANDLE,
        ) callconv(.winapi) win32.HRESULT,
        GetService: *const fn (
            self: *const IAudioClient,
            riid: ?*const win32.GUID,
            ppv: **anyopaque,
        ) callconv(.winapi) win32.HRESULT,
    };
    vtable: *const VTable,
    IUnknown: IUnknown,
    pub inline fn Initialize(self: *const IAudioClient, ShareMode: AUDCLNT_SHAREMODE, StreamFlags: u32, hnsBufferDuration: i64, hnsPeriodicity: i64, pFormat: ?*const WAVEFORMATEX, AudioSessionGuid: ?*const win32.GUID) win32.HRESULT {
        return self.vtable.Initialize(self, ShareMode, StreamFlags, hnsBufferDuration, hnsPeriodicity, pFormat, AudioSessionGuid);
    }
    pub inline fn GetBufferSize(self: *const IAudioClient, pNumBufferFrames: ?*u32) win32.HRESULT {
        return self.vtable.GetBufferSize(self, pNumBufferFrames);
    }
    pub inline fn GetStreamLatency(self: *const IAudioClient, phnsLatency: ?*i64) win32.HRESULT {
        return self.vtable.GetStreamLatency(self, phnsLatency);
    }
    pub inline fn GetCurrentPadding(self: *const IAudioClient, pNumPaddingFrames: ?*u32) win32.HRESULT {
        return self.vtable.GetCurrentPadding(self, pNumPaddingFrames);
    }
    pub inline fn IsFormatSupported(self: *const IAudioClient, ShareMode: AUDCLNT_SHAREMODE, pFormat: ?*const WAVEFORMATEX, ppClosestMatch: ?*?*WAVEFORMATEX) win32.HRESULT {
        return self.vtable.IsFormatSupported(self, ShareMode, pFormat, ppClosestMatch);
    }
    pub inline fn GetMixFormat(self: *const IAudioClient, ppDeviceFormat: ?*?*WAVEFORMATEX) win32.HRESULT {
        return self.vtable.GetMixFormat(self, ppDeviceFormat);
    }
    pub inline fn GetDevicePeriod(self: *const IAudioClient, phnsDefaultDevicePeriod: ?*i64, phnsMinimumDevicePeriod: ?*i64) win32.HRESULT {
        return self.vtable.GetDevicePeriod(self, phnsDefaultDevicePeriod, phnsMinimumDevicePeriod);
    }
    pub inline fn Start(self: *const IAudioClient) win32.HRESULT {
        return self.vtable.Start(self);
    }
    pub inline fn Stop(self: *const IAudioClient) win32.HRESULT {
        return self.vtable.Stop(self);
    }
    pub inline fn Reset(self: *const IAudioClient) win32.HRESULT {
        return self.vtable.Reset(self);
    }
    pub inline fn SetEventHandle(self: *const IAudioClient, eventHandle: ?win32.HANDLE) win32.HRESULT {
        return self.vtable.SetEventHandle(self, eventHandle);
    }
    pub inline fn GetService(self: *const IAudioClient, riid: ?*const win32.GUID, ppv: **anyopaque) win32.HRESULT {
        return self.vtable.GetService(self, riid, ppv);
    }
};

const IID_IAudioRenderClient_Value = GUID.parse("{f294acfc-3146-4483-a7bf-addca7c260e2}");
pub const IID_IAudioRenderClient = &IID_IAudioRenderClient_Value;
pub const IAudioRenderClient = extern union {
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        GetBuffer: *const fn (
            self: *const IAudioRenderClient,
            NumFramesRequested: u32,
            ppData: ?*?[*]u8,
        ) callconv(.winapi) HRESULT,
        ReleaseBuffer: *const fn (
            self: *const IAudioRenderClient,
            NumFramesWritten: u32,
            dwFlags: u32,
        ) callconv(.winapi) HRESULT,
    };
    vtable: *const VTable,
    IUnknown: IUnknown,
    pub inline fn GetBuffer(self: *const IAudioRenderClient, NumFramesRequested: u32, ppData: ?*?[*]u8) HRESULT {
        return self.vtable.GetBuffer(self, NumFramesRequested, ppData);
    }
    pub inline fn ReleaseBuffer(self: *const IAudioRenderClient, NumFramesWritten: u32, dwFlags: u32) HRESULT {
        return self.vtable.ReleaseBuffer(self, NumFramesWritten, dwFlags);
    }
};
