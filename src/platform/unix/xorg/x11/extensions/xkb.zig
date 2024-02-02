const types = @import("../types.zig");

// Constants
pub const XkbMaxLegalKeyCode = 255;
pub const XkbPerKeyBitArraySize = ((XkbMaxLegalKeyCode + 1) / 8);
pub const XkbNumVirtualMods = 16;
pub const XkbAnyActionDataSize = 7;
pub const XkbNumIndicators = 32;
pub const XkbNumKbdGroups = 4;
pub const XkbMaxKbdGroup = (XkbNumKbdGroups - 1);
pub const XkbActionMessageLength = 6;
pub const XkbKeyNameLength = 4;
pub const XkbKeyNumVirtualMods = 16;
pub const XkbKeyNumIndicators = 32;
pub const XkbKeyNumKbdGroups = 4;
pub const XkbMaxRadioGroups = 32;

// Types
pub const XkbAnyEvent = extern struct {
    //       int                type;        /* Xkb extension base event code */
    //       unsigned long      serial;      /* X server serial number for event */
    //       Bool               send_event;  /*  True => synthetically generated */
    //       Display *          display;     /* server connection where event
    // generated */
    //       Time               time;        /* server time when event generated */
    //       int                xkb_type;    /* Xkb minor event code */
    //       unsigned int       device;      /* Xkb device ID, will not be
    //                                          XkbUseCoreKbd */
    type: c_int,
    serial: c_ulong,
    send_event: bool,
    display: ?*types.Display,
    time: types.Time,
    xkb_type: c_int,
    device: c_uint,
};

pub const XkbStateRec = extern struct {
    // unsigned char            group;                /* effective group index */
    // unsigned char            base_group;           /* base group index */
    // unsigned char            latched_group;        /* latched group index */
    // unsigned char            locked_group;         /* locked group index */
    // unsigned char            mods;                 /* effective modifiers */
    // unsigned char            base_mods;            /* base modifiers */
    // unsigned char            latched_mods;         /* latched modifiers */
    // unsigned char            locked_mods;          /* locked modifiers */
    // unsigned char            compat_state;         /* effective group => modifiers */
    // unsigned char            grab_mods;            /* modifiers used for grabs */
    // unsigned char            compat_grab_mods;     /* mods used for compatibility mode grabs */
    // unsigned char            lookup_mods;          /* modifiers used to lookup symbols */
    // unsigned char            compat_lookup_mods;   /* mods used for compatibility lookup */
    // unsigned short            ptr_buttons;         /* 1 bit => corresponding pointer btn is down */
    group: u8,
    base_group: u8,
    latched_group: u8,
    locked_group: u8,
    mods: u8,
    base_mods: u8,
    latched_mods: u8,
    locked_mods: u8,
    compat_state: u8,
    grab_mods: u8,
    compat_grab_mods: u8,
    lookup_mods: u8,
    compate_lookup_mods: u8,
    ptr_buttons: c_ushort,
};

pub const XkbModsRec = extern struct {
    //       unsigned char            mask;            /* real_mods | vmods mapped to
    // real modifiers */
    //       unsigned char            real_mods;            /* real modifier bits */
    //       unsigned short             vmods;            /* virtual modifier bits */
    mask: u8,
    real_mods: u8,
    vmods: c_ushort,
};

pub const XkbAnyAction = extern struct {
    // unsigned char    type;            /* type of action; determines interpretation for data */
    // unsigned char    data[XkbAnyActionDataSize];
    type: u8,
    data: [XkbAnyActionDataSize]u8,
};

pub const XkbModAction = extern struct {
    // unsigned char     type;         /*  XkbSA_{Set|Latch|Lock}Mods */
    // unsigned char     flags;        /* with  type , controls the effect on modifiers */
    // unsigned char     mask;         /* same as  mask field of a modifier description */
    // unsigned char     real_mods;    /* same as  real_mods field of a modifier description */
    // unsigned char     vmods1;       /* derived from  vmods field of a modifier description */
    // unsigned char     vmods2;       /* derived from  vmods field of a modifier description */
    type: u8,
    flags: u8,
    mask: u8,
    real_mods: u8,
    vmods1: u8,
    vmods2: u8,
};

pub const XkbISOAction = extern struct {
    // unsigned char   type;        /* XkbSA_ISOLock */
    // unsigned char   flags;       /* controls changes to group or modifier state */
    // unsigned char   mask;        /* same as mask field of a modifier description */
    // unsigned char   real_mods;   /* same as real_mods field of a modifier description */
    // char            group_XXX;   /* group index or delta group */
    // unsigned char   affect;      /* specifies whether to affect mods, group, ptrbtn, or controls*/
    // unsigned char   vmods1;      /* derived from vmods field of a modifier description */
    // unsigned char   vmods2;      /* derived from vmods field of a modifier description */
    type: u8,
    flags: u8,
    mask: u8,
    real_mods: u8,
    group_XXX: c_char,
    affect: u8,
    vmods1: u8,
    vmods2: u8,
};

pub const XkbGroupAction = extern struct {
    // unsigned char   type;       /*  XkbSA_{Set|Latch|Lock}Group */
    // unsigned char   flags;      /* with  type , controls the effect on groups */
    // char            group_XXX;  /* represents a group index or delta */
    type: u8,
    flags: u8,
    group_XXX: c_char,
};

pub const XkbPtrAction = extern struct {
    // unsigned char      type;      /*  XkbSA_MovePtr */
    // unsigned char      flags;     /* determines type of pointer motion */
    // unsigned char      high_XXX;  /* x coordinate, high bits*/
    // unsigned char      low_XXX;   /* y coordinate, low bits */
    // unsigned char      high_YYY;  /* x coordinate, high bits */
    // unsigned char      low_YYY;   /* y coordinate, low bits */

    type: u8,
    flags: u8,
    high_XXX: u8,
    low_XXX: u8,
    high_YYY: u8,
    low_YYY: u8,
};

pub const XkbPtrBtnAction = extern struct {
    // unsigned char   type;     /* XkbSA_PtrBtn, XkbSA_LockPtrBtn */
    // unsigned char   flags;    /* with  type , controls the effect on pointer buttons*/
    // unsigned char   count;    /* controls number of ButtonPress and ButtonRelease events */
    // unsigned char   button;   /* pointer button to simulate */
    type: u8,
    flags: u8,
    count: u8,
    button: u8,
};

pub const XkbPtrDfltAction = extern struct {
    // unsigned char   type;      /*  XkbSA_SetPtrDflt */
    // unsigned char   flags;     /* controls the pointer button number */
    // unsigned char   affect;    /*  XkbSA_AffectDfltBtn */
    // char            valueXXX;  /* new default button member */

    type: u8,
    flags: u8,
    affect: u8,
    valueXXX: c_char,
};

pub const XkbSwitchScreenAction = extern struct {
    // unsigned char   type;        /*  XkbSA_SwitchScreen */
    // unsigned char   flags;       /* controls screen switching */
    // char            screenXXX;   /* screen number or delta */
    type: u8,
    flags: u8,
    screenXXX: c_char,
};

pub const XkbCtrlsAction = extern struct {
    // unsigned char     type;        /*  XkbSA_SetControls,
    //                                   XkbSA_LockControls */
    // unsigned char     flags;       /* with  type,
    //                                   controls enabling and disabling of controls */
    // unsigned char     ctrls3;      /* ctrls0 through
    //                                    ctrls3 represent the boolean controls */
    // unsigned char     ctrls2;      /* ctrls0 through
    //                                    ctrls3 represent the boolean controls */
    // unsigned char     ctrls1;      /* ctrls0 through
    //                                    ctrls3 represent the boolean controls */
    // unsigned char     ctrls0;      /* ctrls0 through
    //                                    ctrls3 represent the boolean controls */
    type: u8,
    flags: u8,
    ctrls3: u8,
    ctrls2: u8,
    ctrls1: u8,
    ctrls0: u8,
};

pub const XkbMessageAction = extern struct {
    // unsigned char   type;             /*  XkbSA_ActionMessage */
    // unsigned char   flags;            /* controls event generation via key presses and releases */
    // unsigned char   message[XkbActionMessageLength];    /* message */
    type: u8,
    flags: u8,
    message: [XkbActionMessageLength]u8,
};

pub const XkbRedirectKeyAction = extern struct {
    // unsigned char      type;          /*  XkbSA_RedirectKey */
    // unsigned char      new_key;       /* keycode to be put in event */
    // unsigned char      mods_mask;     /* mask of real mods to be reset */
    // unsigned char      mods;          /* mask of real mods to take values from */
    // unsigned char      vmods_mask0;   /* first half of mask of virtual mods to be reset */
    // unsigned char      vmods_mask1;   /* other half of mask of virtual mods to be reset */
    // unsigned char      vmods0;        /* first half of mask of virtual mods to take values from */
    // unsigned char      vmods1;        /* other half of mask of virtual mods to take values from */
    type: u8,
    new_key: u8,
    mods_mask: u8,
    mods: u8,
    vmods_mask0: u8,
    vmods_mask1: u8,
    vmods0: u8,
    vmods1: u8,
};

pub const XkbDeviceBtnAction = extern struct {
    // unsigned char    type;      /*  XkbSA_DeviceBtn, XkbSA_LockDeviceBtn */
    // unsigned char    flags;     /* with  type , specifies locking or unlocking */
    // unsigned char    count;     /* controls number of DeviceButtonPress and Release events */
    // unsigned char    button;    /* index of button on  device */
    // unsigned char    device;    /* device ID of an X input extension device */
    type: u8,
    flags: u8,
    count: u8,
    button: u8,
    device: u8,
};

pub const XkbDeviceValuatorAction = extern struct {
    // unsigned char    type;        /* XkbSA_DeviceValuator */
    // unsigned char    device;      /* device ID */
    // unsigned char    v1_what;     /* determines how valuator is to behave for valuator 1 */
    // unsigned char    v1_ndx;      /* specifies a real valuator */
    // unsigned char    v1_value;    /* the value for valuator 1 */
    // unsigned char    v2_what;     /* determines how valuator is to behave for valuator 2 */
    // unsigned char    v2_ndx;      /* specifies a real valuator */
    // unsigned char    v2_value;    /* the value for valuator 1 */
    type: u8,
    device: u8,
    v1_what: u8,
    v1_ndx: u8,
    v1_value: u8,
    v2_what: u8,
    v2_ndx: u8,
    v2_value: u8,
};

pub const XkbAction = extern union {
    any: XkbAnyAction,
    mods: XkbModAction,
    group: XkbGroupAction,
    iso: XkbISOAction,
    ptr: XkbPtrAction,
    btn: XkbPtrBtnAction,
    dflt: XkbPtrDfltAction,
    screen: XkbSwitchScreenAction,
    ctrls: XkbCtrlsAction,
    msg: XkbMessageAction,
    redirect: XkbRedirectKeyAction,
    devbtn: XkbDeviceBtnAction,
    devval: XkbDeviceValuatorAction,
    type: u8,
};

pub const XkbBehavior = extern struct {

    // unsigned char  type;                  /* behavior type + optional
    //                                           XkbKB_Permanent bit */
    // unsigned char  data;
    type: u8,
    data: u8,
};

pub const XkbControlsRec = extern struct {
    // unsigned char        mk_dflt_btn;       /* default button for keyboard driven mouse */
    // unsigned char        num_groups;        /* number of keyboard groups */
    // unsigned char        groups_wrap;       /* how to wrap out-of-bounds groups */
    // XkbModsRec           internal;          /* defines server internal modifiers */
    // XkbModsRec           ignore_lock;       /* modifiers to ignore when checking for grab */
    // unsigned int         enabled_ctrls;     /* 1 bit => corresponding boolean control enabled */
    // unsigned short       repeat_delay;      /* ms delay until first repeat */
    // unsigned short       repeat_interval;   /* ms delay between repeats */
    // unsigned short       slow_keys_delay;   /* ms minimum time key must be down to be ok */
    // unsigned short       debounce_delay;    /* ms delay before key reactivated */
    // unsigned short       mk_delay;          /* ms delay to second mouse motion event */
    // unsigned short       mk_interval;       /* ms delay between repeat mouse events */
    // unsigned short       mk_time_to_max;    /* # intervals until constant mouse move */
    // unsigned short       mk_max_speed;      /* multiplier for maximum mouse speed */
    // short                mk_curve;          /* determines mouse move curve type */
    // unsigned short       ax_options;        /* 1 bit => Access X option enabled */
    // unsigned short       ax_timeout;        /* seconds until Access X disabled */
    // unsigned short       axt_opts_mask;     /* 1 bit => options to reset on Access X timeout */
    // unsigned short       axt_opts_values;   /* 1 bit => turn option on, 0=> off */
    // unsigned int         axt_ctrls_mask;    /* which bits in  enabled_ctrls to modify */
    // unsigned int         axt_ctrls_values;  /* values for new bits in  enabled_ctrls */
    // unsigned char        per_key_repeat[XkbPerKeyBitArraySize];           /* per key auto repeat */
    mk_dflt_btn: u8,
    num_groups: u8,
    groups_wrap: u8,
    internal: XkbModsRec,
    ignore_lock: XkbModsRec,
    enabled_ctrls: c_uint,
    repeat_delay: c_ushort,
    repeat_interval: c_ushort,
    slow_keys_delay: c_ushort,
    debounce_delay: c_ushort,
    mk_delay: c_ushort,
    mk_interval: c_ushort,
    mk_time_to_max: c_ushort,
    mk_max_speed: c_ushort,
    mk_curve: c_short,
    ax_options: c_ushort,
    ax_timeout: c_ushort,
    axt_opts_mask: c_ushort,
    axt_opts_values: c_ushort,
    axt_ctrls_mask: c_uint,
    axt_ctrls_values: c_uint,
    per_key_repeat: [XkbPerKeyBitArraySize]u8,
};

pub const XkbServerMapRec = extern struct {
    // unsigned short     num_acts;       /* # of occupied entries in  acts */
    // unsigned short     size_acts;      /* # of entries in  acts */
    // XkbAction *        acts;           /* linear 2d tables of key actions, 1 per keycode */
    // XkbBehavior *      behaviors;      /* key behaviors,1 per keycode */
    // unsigned short *   key_acts;       /* index into  acts , 1 per keycode */
    // unsigned char *    explicit;       /* explicit overrides of core remapping, 1 per key */
    // unsigned char      vmods[XkbNumVirtualMods];  /* real mods bound to virtual mods */
    // unsigned short *   vmodmap;        /* virtual mods bound to key, 1 per keycode*/
    num_acts: c_ushort,
    size_acts: c_ushort,
    acts: XkbAction,
    behaviors: XkbBehavior,
    key_acts: ?*c_ushort,
    explicit: ?*u8,
    vmods: [XkbNumVirtualMods]u8,
    vmodmap: ?*c_ushort,
};

pub const XkbKTMapEntryRec = extern struct {
    // /* Modifiers for a key type */
    //   Bool            active;      /*  True => entry
    //                                   active when determining shift level */
    //   unsigned char   level;       /* shift level if modifiers match  mods */
    //   XkbModsRec      mods;        /* mods needed for this level to be
    //                                   selected */
    active: types.Bool,
    level: u8,
    mods: XkbModsRec,
};

pub const XkbKeyTypeRec = extern struct {
    // /* Key Type */
    //   XkbModsRec        mods;          /* modifiers used to compute shift
    //                                       level */
    //   unsigned char     num_levels;    /* total # shift levels, do not
    //                                       modify directly */
    //   unsigned char     map_count;     /* # entries in map,
    //                                        preserve
    //                                       (if non- NULL) */
    //   XkbKTMapEntryPtr  map;           /* vector of modifiers for each
    //                                       shift level */
    //   XkbModsPtr        preserve;      /* mods to preserve for corresponding
    //                                       map entry */
    //   Atom              name;          /* name of key type */
    //   Atom *            level_names;   /* array of names of each shift level */

    mods: XkbModsRec,
    num_levels: u8,
    map_count: u8,
    map: ?[*]XkbKTMapEntryRec,
    preserve: ?*XkbModsRec,
    name: types.Atom,
    level_names: ?[*]types.Atom,
};

pub const XkbSymMapRec = extern struct {
    // /* map to keysyms for a single keycode */
    //   unsigned char     kt_index[XkbNumKbdGroups]; /* key type index for each group */
    //   unsigned char     group_info;                /* # of groups and out of range group handling */
    //   unsigned char     width;                     /* max # of shift levels for key */
    //   unsigned short    offset;                    /* index to keysym table in  syms array */
    kt_index: [XkbNumKbdGroups]u8,
    group_info: u8,
    width: u8,
    offset: c_ushort,
};

pub const XkbClientMapRec = extern struct {
    // /* Client Map */
    //   unsigned char      size_types;    /* # occupied entries in  types */
    //   unsigned char      num_types;     /* # entries in types */
    //   XkbKeyTypePtr      types;         /* vector of key types used by this keymap */
    //   unsigned short     size_syms;     /* length of the syms array */
    //   unsigned short     num_syms;      /* # entries in syms */
    //   KeySym *           syms;          /* linear 2d tables of keysyms, 1 per key */
    //   XkbSymMapPtr       key_sym_map;   /* 1 per keycode, maps keycode to syms */
    //   unsigned char *    modmap;        /* 1 per keycode, real mods bound to key */
    size_types: u8,
    num_types: u8,
    types: ?[*]XkbKeyTypeRec,
    size_syms: c_ushort,
    num_syms: c_ushort,
    syms: ?[*]types.KeySym,
    key_sym_map: ?*XkbSymMapRec,
    modmap: ?*u8,
};

pub const XkbIndicatorMapRec = extern struct {
    // unsigned char    flags;         /* how the indicator can be changed */
    // unsigned char    which_groups;  /* match criteria for groups */
    // unsigned char    groups;        /* which keyboard groups the indicator watches */
    // unsigned char    which_mods;    /* match criteria for modifiers */
    // XkbModsRec       mods;          /* which modifiers the indicator watches */
    // unsigned int     ctrls;         /* which controls the indicator watches */
    flags: u8,
    which_groups: u8,
    groups: u8,
    which_mods: u8,
    mods: XkbModsRec,
    ctrls: c_uint,
};

pub const XkbIndicatorRec = extern struct {
    // unsigned long                   phys_indicators;        /* LEDs existence */
    // XkbIndicatorMapRec              maps[XkbNumIndicators]; /* indicator maps */
    phys_indicators: c_ulong,
    maps: [XkbNumIndicators]XkbIndicatorMapRec,
};

pub const XkbKeyNameRec = extern struct {
    // char      name[XkbKeyNameLength];      /* symbolic key names */
    name: [XkbKeyNameLength]c_char,
};

pub const XkbKeyAliasRec = extern struct {
    // char      real[XkbKeyNameLength];
    //           /* this key name must be in the keys array */
    // char      alias[XkbKeyNameLength];
    //           /* symbolic key name as alias for the key */
    real: [XkbKeyNameLength]c_char,
    alias: [XkbKeyNameLength]c_char,
};

pub const XkbNamesRec = extern struct {
    // Atom      keycodes;      /* identifies range and meaning of keycodes */
    // Atom      geometry;      /* identifies physical location, size, and shape of keys */
    // Atom      symbols;       /* identifies the symbols logically bound to the keys */
    // Atom      types;         /* identifies the set of key types */
    // Atom      compat;        /* identifies actions for keys using core protocol */
    // Atom      vmods[XkbNumVirtualMods]; /* symbolic names for virtual modifiers */
    // Atom      indicators[XkbNumIndicators];   /* symbolic names for indicators */
    // Atom      groups[XkbNumKbdGroups]; /* symbolic names for keyboard groups */
    // XkbKeyNamePtr      keys;         /* symbolic key name array */
    // XkbKeyAliasPtr     key_aliases;  /* real/alias symbolic name pairs array */
    // Atom *    radio_groups;      /* radio group name array */
    // Atom      phys_symbols;      /* identifies the symbols engraved on the keyboard */
    // unsigned char      num_keys; /* number of keys in the  keys array */
    // unsigned char      num_key_aliases;  /* number of keys in the
    //                                          key_aliases array */
    // unsigned short     num_rg;      /* number of radio groups */
    keycodes: types.Atom,
    geometry: types.Atom,
    symbols: types.Atom,
    types: types.Atom,
    compat: types.Atom,
    vmods: [XkbNumVirtualMods]types.Atom,
    indicators: [XkbNumIndicators]types.Atom,
    groups: [XkbNumKbdGroups]types.Atom,
    keys: ?*XkbKeyNameRec,
    key_aliases: ?*XkbKeyAliasRec,
    num_keys: u8,
    num_key_aliases: u8,
    num_rg: c_ushort,
};

pub const XkbSymInterpretRec = extern struct {
    // KeySym          sym;          /* keysym of interest or NULL */
    // unsigned char   flags;        /* XkbSI_AutoRepeat, XkbSI_LockingKey */
    // unsigned char   match;        /* specifies how mods is interpreted */
    // unsigned char   mods;         /* modifier bits, correspond to eight real modifiers */
    // unsigned char   virtual_mod;  /* 1 modifier to add to key virtual mod map */
    // XkbAnyAction    act;          /* action to bind to symbol position on key */
    sym: types.KeySym,
    flags: u8,
    match: u8,
    mods: u8,
    virtual_mod: u8,
    act: XkbAnyAction,
};

pub const XkbCompatMapRec = extern struct {
    // XkbSymInterpretPtr   sym_interpret;            /* symbol based key semantics*/
    // XkbModsRec           groups[XkbNumKbdGroups];  /* group => modifier map */
    // unsigned short       num_si;                   /* # structures used in
    //                                                   sym_interpret */
    // unsigned short       size_si;                  /* # structures allocated in
    //                                                   sym_interpret */
    //
    sym_interpret: ?*XkbSymInterpretRec,
    groups: [XkbNumKbdGroups]XkbModsRec,
    num_si: c_ushort,
    size_si: c_ushort,
};

pub const XkbDescRec = extern struct {
    //       struct _XDisplay *                  display;            /* connection to
    // X server */
    //       unsigned short                  flags;            /* private to Xkb, do
    // not modify */
    //       unsigned short                  device_spec;            /* device of
    // interest */
    //       KeyCode                  min_key_code;            /* minimum keycode for
    // device */
    //       KeyCode                  max_key_code;            /* maximum keycode for
    // device */
    //       XkbControlsPtr                  ctrls;            /* controls */
    //       XkbServerMapPtr                  server;            /* server keymap */
    //       XkbClientMapPtr                  map;            /* client keymap */
    //       XkbIndicatorPtr                  indicators;            /* indicator map
    // */
    //       XkbNamesPtr                  names;            /* names for all
    // components */
    //       XkbCompatMapPtr                  compat;            /* compatibility map
    // */
    //       XkbGeometryPtr                  geom;            /* physical geometry of
    // keyboard */
    display: ?*types.Display,
    flags: c_ushort,
    device_spec: c_ushort,
    min_key_code: types.KeyCode,
    max_key_code: types.KeyCode,
    ctrls: ?*XkbControlsRec,
    server: ?*XkbServerMapRec,
    map: ?*XkbClientMapRec,
    indicators: ?*XkbIndicatorRec,
    names: ?*XkbNamesRec,
    compat: ?*XkbCompatMapRec,
    //TODO:
    geom: anyopaque,
};

// Functions signatures
pub const XkbLibraryVersionProc = *const fn (
    lib_major_in_out: ?*c_int,
    lib_minor_in_out: ?*c_int,
) callconv(.C) types.Bool;
pub const XkbQueryExtensionProc = *const fn (
    dpy: ??*types.Display,
    opcode_rtrn: ?*c_int,
    event_rtrn: ?*c_int,
    error_rtrn: ?*c_int,
    major_in_out: ?*c_int,
    minor_in_out: ?*c_int,
) callconv(.C) types.Bool;
pub const XkbGetDetectableAutorepeatProc = *const fn (
    display: ?*types.Display,
    supported_rtrn: ?*types.Bool,
) callconv(.C) types.Bool;
pub const XkbSetDetectableAutorepeatProc = *const fn (
    display: ?*types.Display,
    detectable: types.Bool,
    supported_rtrn: ?*types.Bool,
) callconv(.C) types.Bool;
pub const XkbGetStateProc = *const fn (
    display: ?*types.Display,
    device_spec: c_uint,
    state_return: ?*XkbStateRec,
) callconv(.C) types.Status;
pub const XkbGetNamesProc = *const fn (
    display: ?*types.Display,
    which: c_uint,
    Xkb: ?*XkbDescRec,
) callconv(.C) types.Status;
pub const XkbGetMapProc = *const fn (
    display: ?*types.Display,
    which: c_uint,
    device_spec: c_uint,
) callconv(.C) ?*XkbDescRec;
pub const XkbFreeNamesProc = *const fn (
    Xkb: ?*XkbDescRec,
    which: c_uint,
    free_map: type.Bool,
) callconv(.C) void;
pub const XkbAllocKeyboardProc = *const fn () callconv(.C) ?*XkbDescRec;
pub const XkbFreeKeyboardProc = *const fn (
    Xkb: ?*XkbDescRec,
    which: c_uint,
    free_all: type.Bool,
) callconv(.C) void;
pub const XkbKeycodeToKeysymProc = *const fn (
    display: ?*types.Display,
    kc: types.KeyCode,
    group: c_uint,
    level: c_uint,
) callconv(.C) types.KeySym;
pub const XkbSelectEventDetailsProc = *const fn (
    display: ?*types.Display,
    device_spec: c_uint,
    event_type: c_uint,
    bits_to_change: c_ulong,
    values_for_bits: c_ulong,
) callconv(.C) types.Bool;
