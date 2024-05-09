//! X11 constants
const builtin = @import("builtin");

pub const AllocNone = 0;
pub const AllocAll = 1;

pub const XA_PRIMARY = 1;
pub const XA_SECONDARY = 2;
pub const XA_ARC = 3;
pub const XA_ATOM = 4;
pub const XA_BITMAP = 5;
pub const XA_CARDINAL = 6;
pub const XA_COLORMAP = 7;
pub const XA_CURSOR = 8;
pub const XA_CUT_BUFFER0 = 9;
pub const XA_CUT_BUFFER1 = 10;
pub const XA_CUT_BUFFER2 = 11;
pub const XA_CUT_BUFFER3 = 12;
pub const XA_CUT_BUFFER4 = 13;
pub const XA_CUT_BUFFER5 = 14;
pub const XA_CUT_BUFFER6 = 15;
pub const XA_CUT_BUFFER7 = 16;
pub const XA_DRAWABLE = 17;
pub const XA_FONT = 18;
pub const XA_INTEGER = 19;
pub const XA_PIXMAP = 20;
pub const XA_POINT = 21;
pub const XA_RECTANGLE = 22;
pub const XA_RESOURCE_MANAGER = 23;
pub const XA_RGB_COLOR_MAP = 24;
pub const XA_RGB_BEST_MAP = 25;
pub const XA_RGB_BLUE_MAP = 26;
pub const XA_RGB_DEFAULT_MAP = 27;
pub const XA_RGB_GRAY_MAP = 28;
pub const XA_RGB_GREEN_MAP = 29;
pub const XA_RGB_RED_MAP = 30;
pub const XA_STRING = 31;
pub const XA_VISUALID = 32;
pub const XA_WINDOW = 33;
pub const XA_WM_COMMAND = 34;
pub const XA_WM_HINTS = 35;
pub const XA_WM_CLIENT_MACHINE = 36;
pub const XA_WM_ICON_NAME = 37;
pub const XA_WM_ICON_SIZE = 38;
pub const XA_WM_NAME = 39;
pub const XA_WM_NORMAL_HINTS = 40;
pub const XA_WM_SIZE_HINTS = 41;
pub const XA_WM_ZOOM_HINTS = 42;
pub const XA_MIN_SPACE = 43;
pub const XA_NORM_SPACE = 44;
pub const XA_MAX_SPACE = 45;
pub const XA_END_SPACE = 46;
pub const XA_SUPERSCRIPT_X = 47;
pub const XA_SUPERSCRIPT_Y = 48;
pub const XA_SUBSCRIPT_X = 49;
pub const XA_SUBSCRIPT_Y = 50;
pub const XA_UNDERLINE_POSITION = 51;
pub const XA_UNDERLINE_THICKNESS = 52;
pub const XA_STRIKEOUT_ASCENT = 53;
pub const XA_STRIKEOUT_DESCENT = 54;
pub const XA_ITALIC_ANGLE = 55;
pub const XA_X_HEIGHT = 56;
pub const XA_QUAD_WIDTH = 57;
pub const XA_WEIGHT = 58;
pub const XA_POINT_SIZE = 59;
pub const XA_RESOLUTION = 60;
pub const XA_COPYRIGHT = 61;
pub const XA_NOTICE = 62;
pub const XA_FONT_NAME = 63;
pub const XA_FAMILY_NAME = 64;
pub const XA_FULL_NAME = 65;
pub const XA_CAP_HEIGHT = 66;
pub const XA_WM_CLASS = 67;
pub const XA_WM_TRANSIENT_FOR = 68;

// boolean values
pub const False = 0;
pub const True = 1;

// clip rect ordering
pub const Unsorted = 0;
pub const YSorted = 1;
pub const YXSorted = 2;
pub const YXBanded = 3;

// color component mask
pub const DoRed = 1;
pub const DoGreen = 2;
pub const DoBlue = 4;

// error codes
pub const Success = 0;
pub const BadRequest = 1;
pub const BadValue = 2;
pub const BadWindow = 3;
pub const BadPixmap = 4;
pub const BadAtom = 5;
pub const BadCursor = 6;
pub const BadFont = 7;
pub const BadMatch = 8;
pub const BadDrawable = 9;
pub const BadAccess = 10;
pub const BadAlloc = 11;
pub const BadColor = 12;
pub const BadGC = 13;
pub const BadIDChoice = 14;
pub const BadName = 15;
pub const BadLength = 16;
pub const BadImplementation = 17;
pub const FirstExtensionError = 128;
pub const LastExtensionError = 255;

// event kinds
pub const KeyPress = 2;
pub const KeyRelease = 3;
pub const ButtonPress = 4;
pub const ButtonRelease = 5;
pub const MotionNotify = 6;
pub const EnterNotify = 7;
pub const LeaveNotify = 8;
pub const FocusIn = 9;
pub const FocusOut = 10;
pub const KeymapNotify = 11;
pub const Expose = 12;
pub const GraphicsExpose = 13;
pub const NoExpose = 14;
pub const VisibilityNotify = 15;
pub const CreateNotify = 16;
pub const DestroyNotify = 17;
pub const UnmapNotify = 18;
pub const MapNotify = 19;
pub const MapRequest = 20;
pub const ReparentNotify = 21;
pub const ConfigureNotify = 22;
pub const ConfigureRequest = 23;
pub const GravityNotify = 24;
pub const ResizeRequest = 25;
pub const CirculateNotify = 26;
pub const CirculateRequest = 27;
pub const PropertyNotify = 28;
pub const SelectionClear = 29;
pub const SelectionRequest = 30;
pub const SelectionNotify = 31;
pub const ColormapNotify = 32;
pub const ClientMessage = 33;
pub const MappingNotify = 34;
pub const GenericEvent = 35;
pub const LASTEvent = 36;

// event mask
pub const NoEventMask = 0;
pub const KeyPressMask = 0x0000_0001;
pub const KeyReleaseMask = 0x0000_0002;
pub const ButtonPressMask = 0x0000_0004;
pub const ButtonReleaseMask = 0x0000_0008;
pub const EnterWindowMask = 0x0000_0010;
pub const LeaveWindowMask = 0x0000_0020;
pub const PointerMotionMask = 0x0000_0040;
pub const PointerMotionHintMask = 0x0000_0080;
pub const Button1MotionMask = 0x0000_0100;
pub const Button2MotionMask = 0x0000_0200;
pub const Button3MotionMask = 0x0000_0400;
pub const Button4MotionMask = 0x0000_0800;
pub const Button5MotionMask = 0x0000_1000;
pub const ButtonMotionMask = 0x0000_2000;
pub const KeymapStateMask = 0x0000_4000;
pub const ExposureMask = 0x0000_8000;
pub const VisibilityChangeMask = 0x0001_0000;
pub const StructureNotifyMask = 0x0002_0000;
pub const ResizeRedirectMask = 0x0004_0000;
pub const SubstructureNotifyMask = 0x0008_0000;
pub const SubstructureRedirectMask = 0x0010_0000;
pub const FocusChangeMask = 0x0020_0000;
pub const PropertyChangeMask = 0x0040_0000;
pub const ColormapChangeMask = 0x0080_0000;
pub const OwnerGrabButtonMask = 0x0100_0000;
pub const QueuedAlready = 0;
pub const QueuedAfterReading = 1;
pub const QueuedAfterFlush = 2;

// property modes
pub const PropModeReplace = 0;
pub const PropModePrepend = 1;
pub const PropModeAppend = 2;

// modifier names
pub const ShiftMapIndex = 0;
pub const LockMapIndex = 1;
pub const ControlMapIndex = 2;
pub const Mod1MapIndex = 3;
pub const Mod2MapIndex = 4;
pub const Mod3MapIndex = 5;
pub const Mod4MapIndex = 6;
pub const Mod5MapIndex = 7;

// button masks
pub const Button1Mask = 1 << 8;
pub const Button2Mask = 1 << 9;
pub const Button3Mask = 1 << 10;
pub const Button4Mask = 1 << 11;
pub const Button5Mask = 1 << 12;
pub const AnyModifier = 1 << 15;

// Notify modes
pub const NotifyNormal = 0;
pub const NotifyGrab = 1;
pub const NotifyUngrab = 2;
pub const NotifyWhileGrabbed = 3;

pub const NotifyHint = 1;

// Notify detail
pub const NotifyAncestor = 0;
pub const NotifyVirtual = 1;
pub const NotifyInferior = 2;
pub const NotifyNonlinear = 3;
pub const NotifyNonlinearVirtual = 4;
pub const NotifyPointer = 5;
pub const NotifyPointerRoot = 6;
pub const NotifyDetailNone = 7;

// Visibility notify
pub const VisibilityUnobscured = 0;
pub const VisibilityPartiallyObscured = 1;
pub const VisibilityFullyObscured = 2;

// Circulation request
pub const PlaceOnTop = 0;
pub const PlaceOnBottom = 1;

// protocol families
pub const FamilyInternet = 0;
pub const FamilyDECnet = 1;
pub const FamilyChaos = 2;
pub const FamilyInternet6 = 6;

// authentication families not tied to a specific protocol
pub const FamilyServerInterpreted = 5;

// property notification
pub const PropertyNewValue = 0;
pub const PropertyDelete = 1;

// Color Map notification
pub const ColormapUninstalled = 0;
pub const ColormapInstalled = 1;

// grab modes
pub const GrabModeSync = 0;
pub const GrabModeAsync = 1;

// grab status
pub const GrabSuccess = 0;
pub const AlreadyGrabbed = 1;
pub const GrabInvalidTime = 2;
pub const GrabNotViewable = 3;
pub const GrabFrozen = 4;

// AllowEvents modes
pub const AsyncPointer = 0;
pub const SyncPointer = 1;
pub const ReplayPointer = 2;
pub const AsyncKeyboard = 3;
pub const SyncKeyboard = 4;
pub const ReplayKeyboard = 5;
pub const AsyncBoth = 6;
pub const SyncBoth = 7;

// Used in SetInputFocus, GetInputFocus
pub const RevertToNone = 0;
pub const RevertToPointerRoot = 1;
pub const RevertToParent = 2;

// ConfigureWindow structure
pub const CWX = 1 << 0;
pub const CWY = 1 << 1;
pub const CWWidth = 1 << 2;
pub const CWHeight = 1 << 3;
pub const CWBorderWidth = 1 << 4;
pub const CWSibling = 1 << 5;
pub const CWStackMode = 1 << 6;

// gravity
pub const ForgetGravity = 0;
pub const UnmapGravity = 0;
pub const NorthWestGravity = 1;
pub const NorthGravity = 2;
pub const NorthEastGravity = 3;
pub const WestGravity = 4;
pub const CenterGravity = 5;
pub const EastGravity = 6;
pub const SouthWestGravity = 7;
pub const SouthGravity = 8;
pub const SouthEastGravity = 9;
pub const StaticGravity = 10;

// image format
pub const XYBitmap = 0;
pub const XYPixmap = 1;
pub const ZPixmap = 2;

// Used in CreateWindow for backing-store hint
pub const NotUseful = 0;
pub const WhenMapped = 1;
pub const Always = 2;

// map state
pub const IsUnmapped = 0;
pub const IsUnviewable = 1;
pub const IsViewable = 2;

// modifier keys mask
pub const ShiftMask = 0x01;
pub const LockMask = 0x02;
pub const ControlMask = 0x04;
pub const Mod1Mask = 0x08;
pub const Mod2Mask = 0x10;
pub const Mod3Mask = 0x20;
pub const Mod4Mask = 0x40;
pub const Mod5Mask = 0x80;

pub const Button1 = 1;
pub const Button2 = 2;
pub const Button3 = 3;
pub const Button4 = 4;
pub const Button5 = 5;
pub const Button6 = 6;
pub const Button7 = 7;

pub const USPosition = 0x0001;
pub const USSize = 0x0002;
pub const PPosition = 0x0004;
pub const PSize = 0x0008;
pub const PMinSize = 0x0010;
pub const PMaxSize = 0x0020;
pub const PResizeInc = 0x0040;
pub const PAspect = 0x0080;
pub const PBaseSize = 0x0100;
pub const PWinGravity = 0x0200;
pub const PAllHints = PPosition | PSize | PMinSize | PMaxSize | PResizeInc | PAspect;

pub const SetModeInsert = 0;
pub const SetModeDelete = 1;

pub const DestroyAll = 0;
pub const RetainPermanent = 1;
pub const RetainTemporary = 2;

pub const Above = 0;
pub const Below = 1;
pub const TopIf = 2;
pub const BottomIf = 3;
pub const Opposite = 4;

pub const RaiseLowest = 0;
pub const LowerHighest = 1;

pub const GXclear = 0x0;
pub const GXand = 0x1;
pub const GXandReverse = 0x2;
pub const GXcopy = 0x3;
pub const GXandInverted = 0x4;
pub const GXnoop = 0x5;
pub const GXxor = 0x6;
pub const GXor = 0x7;
pub const GXnor = 0x8;
pub const GXequiv = 0x9;
pub const GXinvert = 0xa;
pub const GXorReverse = 0xb;
pub const GXcopyInverted = 0xc;
pub const GXorInverted = 0xd;
pub const GXnand = 0xe;
pub const GXset = 0xf;

pub const LineSolid = 0;
pub const LineOnOffDash = 1;
pub const LineDoubleDash = 2;

pub const CapNotLast = 0;
pub const CapButt = 1;
pub const CapRound = 2;
pub const CapProjecting = 3;

pub const JoinMiter = 0;
pub const JoinRound = 1;
pub const JoinBevel = 2;

pub const FillSolid = 0;
pub const FillTiled = 1;
pub const FillStippled = 2;
pub const FillOpaqueStippled = 3;

pub const EvenOddRule = 0;
pub const WindingRule = 1;

pub const ClipByChildren = 0;
pub const IncludeInferiors = 1;

pub const CoordModeOrigin = 0;
pub const CoordModePrevious = 1;

pub const Complex = 0;
pub const Nonconvex = 1;
pub const Convex = 2;

pub const ArcChord = 0;
pub const ArcPieSlice = 1;

pub const GCFunction = 1 << 0;
pub const GCPlaneMask = 1 << 1;
pub const GCForeground = 1 << 2;
pub const GCBackground = 1 << 3;
pub const GCLineWidth = 1 << 4;
pub const GCLineStyle = 1 << 5;
pub const GCCapStyle = 1 << 6;
pub const GCJoinStyle = 1 << 7;
pub const GCFillStyle = 1 << 8;
pub const GCFillRule = 1 << 9;
pub const GCTile = 1 << 10;
pub const GCStipple = 1 << 11;
pub const GCTileStipXOrigin = 1 << 12;
pub const GCTileStipYOrigin = 1 << 13;
pub const GCFont = 1 << 14;
pub const GCSubwindowMode = 1 << 15;
pub const GCGraphicsExposures = 1 << 16;
pub const GCClipXOrigin = 1 << 17;
pub const GCClipYOrigin = 1 << 18;
pub const GCClipMask = 1 << 19;
pub const GCDashOffset = 1 << 20;
pub const GCDashList = 1 << 21;
pub const GCArcMode = 1 << 22;

pub const GCLastBit = 22;

pub const FontLeftToRight = 0;
pub const FontRightToLeft = 1;

pub const FontChange = 255;

pub const CursorShape = 0;
pub const TileShape = 1;
pub const StippleShape = 2;

pub const AutoRepeatModeOff = 0;
pub const AutoRepeatModeOn = 1;
pub const AutoRepeatModeDefault = 2;

pub const LedModeOff = 0;
pub const LedModeOn = 1;

pub const KBKeyClickPercent = 1 << 0;
pub const KBBellPercent = 1 << 1;
pub const KBBellPitch = 1 << 2;
pub const KBBellDuration = 1 << 3;
pub const KBLed = 1 << 4;
pub const KBLedMode = 1 << 5;
pub const KBKey = 1 << 6;
pub const KBAutoRepeatMode = 1 << 7;

pub const MappingSuccess = 0;
pub const MappingBusy = 1;
pub const MappingFailed = 2;

pub const MappingModifier = 0;
pub const MappingKeyboard = 1;
pub const MappingPointer = 2;

pub const DontPreferBlanking = 0;
pub const PreferBlanking = 1;
pub const DefaultBlanking = 2;

pub const DisableScreenSaver = 0;
pub const DisableScreenInterval = 0;

pub const DontAllowExposures = 0;
pub const AllowExposures = 1;
pub const DefaultExposures = 2;

pub const ScreenSaverReset = 0;
pub const ScreenSaverActive = 1;

pub const HostInsert = 0;
pub const HostDelete = 1;

pub const EnableAccess = 1;
pub const DisableAccess = 0;

pub const StaticGray = 0;
pub const GrayScale = 1;
pub const StaticColor = 2;
pub const PseudoColor = 3;
pub const TrueColor = 4;
pub const DirectColor = 5;

pub const VisualNoMask = 0x0000;
pub const VisualIDMask = 0x0001;
pub const VisualScreenMask = 0x0002;
pub const VisualDepthMask = 0x0004;
pub const VisualClassMask = 0x0008;
pub const VisualRedMaskMask = 0x0010;
pub const VisualGreenMaskMask = 0x0020;
pub const VisualBlueMaskMask = 0x0040;
pub const VisualColormapSizeMask = 0x0080;
pub const VisualBitsPerRGBMask = 0x0100;
pub const VisualAllMask = 0x01ff;

pub const CWBackPixmap = 0x0001;
pub const CWBackPixel = 0x0002;
pub const CWBorderPixmap = 0x0004;
pub const CWBorderPixel = 0x0008;
pub const CWBitGravity = 0x0010;
pub const CWWinGravity = 0x0020;
pub const CWBackingStore = 0x0040;
pub const CWBackingPlanes = 0x0080;
pub const CWBackingPixel = 0x0100;
pub const CWOverrideRedirect = 0x0200;
pub const CWSaveUnder = 0x0400;
pub const CWEventMask = 0x0800;
pub const CWDontPropagate = 0x1000;
pub const CWColormap = 0x2000;
pub const CWCursor = 0x4000;

pub const InputOutput = 1;
pub const InputOnly = 2;

pub const XIMPreeditArea = 0x0001;
pub const XIMPreeditCallbacks = 0x0002;
pub const XIMPreeditPosition = 0x0004;
pub const XIMPreeditNothing = 0x0008;
pub const XIMPreeditNone = 0x0010;
pub const XIMStatusArea = 0x0100;
pub const XIMStatusCallbacks = 0x0200;
pub const XIMStatusNothing = 0x0400;
pub const XIMStatusNone = 0x0800;

pub const LSBFirst = 0;
pub const MSBFirst = 1;

pub const None = 0;
pub const ParentRelative = 1;
pub const CopyFromParent = 0;
pub const PointerWindow = 0;
pub const InputFocus = 1;
pub const PointerRoot = 1;
pub const AnyPropertyType = 0;
pub const AnyKey = 0;
pub const AnyButton = 0;
pub const AllTemporary = 0;
pub const CurrentTime = 0;
pub const NoSymbol = 0;

pub const X_PROTOCOL = 11;
pub const X_PROTOCOL_REVISION = 0;

pub const XNVaNestedList = "XNVaNestedList";
pub const XNQueryInputStyle = "queryInputStyle";
pub const XNClientWindow = "clientWindow";
pub const XNInputStyle = "inputStyle";
pub const XNFocusWindow = "focusWindow";
pub const XNResourceName = "resourceName";
pub const XNResourceClass = "resourceClass";
pub const XNGeometryCallback = "geometryCallback";
pub const XNDestroyCallback = "destroyCallback";
pub const XNFilterEvents = "filterEvents";
pub const XNPreeditStartCallback = "preeditStartCallback";
pub const XNPreeditDoneCallback = "preeditDoneCallback";
pub const XNPreeditDrawCallback = "preeditDrawCallback";
pub const XNPreeditCaretCallback = "preeditCaretCallback";
pub const XNPreeditStateNotifyCallback = "preeditStateNotifyCallback";
pub const XNPreeditAttributes = "preeditAttributes";
pub const XNStatusStartCallback = "statusStartCallback";
pub const XNStatusDoneCallback = "statusDoneCallback";
pub const XNStatusDrawCallback = "statusDrawCallback";
pub const XNStatusAttributes = "statusAttributes";
pub const XNArea = "area";
pub const XNAreaNeeded = "areaNeeded";
pub const XNSpotLocation = "spotLocation";
pub const XNColormap = "colorMap";
pub const XNStdColormap = "stdColorMap";
pub const XNForeground = "foreground";
pub const XNBackground = "background";
pub const XNBackgroundPixmap = "backgroundPixmap";
pub const XNFontSet = "fontSet";
pub const XNLineSpace = "lineSpace";
pub const XNCursor = "cursor";

pub const XNVaNestedList_0 = "XNVaNestedList";
pub const XNQueryInputStyle_0 = "queryInputStyle";
pub const XNClientWindow_0 = "clientWindow";
pub const XNInputStyle_0 = "inputStyle";
pub const XNFocusWindow_0 = "focusWindow";
pub const XNResourceName_0 = "resourceName";
pub const XNResourceClass_0 = "resourceClass";
pub const XNGeometryCallback_0 = "geometryCallback";
pub const XNDestroyCallback_0 = "destroyCallback";
pub const XNFilterEvents_0 = "filterEvents";
pub const XNPreeditStartCallback_0 = "preeditStartCallback";
pub const XNPreeditDoneCallback_0 = "preeditDoneCallback";
pub const XNPreeditDrawCallback_0 = "preeditDrawCallback";
pub const XNPreeditCaretCallback_0 = "preeditCaretCallback";
pub const XNPreeditStateNotifyCallback_0 = "preeditStateNotifyCallback";
pub const XNPreeditAttributes_0 = "preeditAttributes";
pub const XNStatusStartCallback_0 = "statusStartCallback";
pub const XNStatusDoneCallback_0 = "statusDoneCallback";
pub const XNStatusDrawCallback_0 = "statusDrawCallback";
pub const XNStatusAttributes_0 = "statusAttributes";
pub const XNArea_0 = "area";
pub const XNAreaNeeded_0 = "areaNeeded";
pub const XNSpotLocation_0 = "spotLocation";
pub const XNColormap_0 = "colorMap";
pub const XNStdColormap_0 = "stdColorMap";
pub const XNForeground_0 = "foreground";
pub const XNBackground_0 = "background";
pub const XNBackgroundPixmap_0 = "backgroundPixmap";
pub const XNFontSet_0 = "fontSet";
pub const XNLineSpace_0 = "lineSpace";
pub const XNCursor_0 = "cursor";

pub const XNQueryIMValuesList = "queryIMValuesList";
pub const XNQueryICValuesList = "queryICValuesList";
pub const XNVisiblePosition = "visiblePosition";
pub const XNR6PreeditCallback = "r6PreeditCallback";
pub const XNStringConversionCallback = "stringConversionCallback";
pub const XNStringConversion = "stringConversion";
pub const XNResetState = "resetState";
pub const XNHotKey = "hotKey";
pub const XNHotKeyState = "hotKeyState";
pub const XNPreeditState = "preeditState";
pub const XNSeparatorofNestedList = "separatorofNestedList";

pub const XNQueryIMValuesList_0 = "queryIMValuesList";
pub const XNQueryICValuesList_0 = "queryICValuesList";
pub const XNVisiblePosition_0 = "visiblePosition";
pub const XNR6PreeditCallback_0 = "r6PreeditCallback";
pub const XNStringConversionCallback_0 = "stringConversionCallback";
pub const XNStringConversion_0 = "stringConversion";
pub const XNResetState_0 = "resetState";
pub const XNHotKey_0 = "hotKey";
pub const XNHotKeyState_0 = "hotKeyState";
pub const XNPreeditState_0 = "preeditState";
pub const XNSeparatorofNestedList_0 = "separatorofNestedList";

pub const XBufferOverflow = -1;
pub const XLookupNone = 1;
pub const XLookupChars = 2;
pub const XLookupKeySym = 3;
pub const XLookupBoth = 4;

pub const NoValue = 0x0000;
pub const XValue = 0x0001;
pub const YValue = 0x0002;
pub const WidthValue = 0x0004;
pub const HeightValue = 0x0008;
pub const AllValues = 0x000f;
pub const XNegative = 0x0010;
pub const YNegative = 0x0020;

pub const InputHint = 1 << 0;
pub const StateHint = 1 << 1;
pub const IconPixmapHint = 1 << 2;
pub const IconWindowHint = 1 << 3;
pub const IconPositionHint = 1 << 4;
pub const IconMaskHint = 1 << 5;
pub const WindowGroupHint = 1 << 6;
pub const AllHints = InputHint |
    StateHint |
    IconPixmapHint |
    IconWindowHint |
    IconPositionHint |
    IconMaskHint |
    WindowGroupHint;
pub const XUrgencyHint = 1 << 8;
pub const XStringStyle = 0;
pub const XCompoundTextStyle = 1;
pub const XTextStyle = 2;
pub const XStdICCTextStyle = 3;
pub const XUTF8StringStyle = 4;

pub const NormalState = 1;
pub const IconicState = 3;

/// Determine the modules name at comptime.
pub const XORG_LIBS_NAME = switch (builtin.target.os.tag) {
    .linux => [_][*:0]const u8{
        "libX11.so.6", "libXrandr.so.2", "libXinerama.so.1",
    },
    .freebsd, .netbsd, .openbsd => [_][*:0]const u8{
        "libX11.so", "libXrandr.so", "libXinerama.so",
    },
    else => @compileError("Unsupported Unix Platform"),
};

pub const LIB_X11_INDEX = 0;
pub const LIB_XRANDR_INDEX = 1;
pub const LIB_XINERAMA_INDEX = 2;
