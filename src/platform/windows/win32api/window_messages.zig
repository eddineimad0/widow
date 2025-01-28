const win32 = @import("std").os.windows;

//=======================
// Constants
//========================
pub const WM_NULL = @as(u32, 0);
pub const WM_CREATE = @as(u32, 1);
pub const WM_DESTROY = @as(u32, 2);
pub const WM_MOVE = @as(u32, 3);
pub const WM_SIZE = @as(u32, 5);
pub const WM_ACTIVATE = @as(u32, 6);
pub const WA_INACTIVE = @as(u32, 0);
pub const WA_ACTIVE = @as(u32, 1);
pub const WA_CLICKACTIVE = @as(u32, 2);
pub const WM_SETFOCUS = @as(u32, 7);
pub const WM_KILLFOCUS = @as(u32, 8);
pub const WM_ENABLE = @as(u32, 10);
pub const WM_SETREDRAW = @as(u32, 11);
pub const WM_SETTEXT = @as(u32, 12);
pub const WM_GETTEXT = @as(u32, 13);
pub const WM_GETTEXTLENGTH = @as(u32, 14);
pub const WM_PAINT = @as(u32, 15);
pub const WM_CLOSE = @as(u32, 16);
pub const WM_QUERYENDSESSION = @as(u32, 17);
pub const WM_QUERYOPEN = @as(u32, 19);
pub const WM_ENDSESSION = @as(u32, 22);
pub const WM_QUIT = @as(u32, 18);
pub const WM_ERASEBKGND = @as(u32, 20);
pub const WM_SYSCOLORCHANGE = @as(u32, 21);
pub const WM_SHOWWINDOW = @as(u32, 24);
pub const WM_WININICHANGE = @as(u32, 26);
pub const WM_SETTINGCHANGE = @as(u32, 26);
pub const WM_DEVMODECHANGE = @as(u32, 27);
pub const WM_ACTIVATEAPP = @as(u32, 28);
pub const WM_FONTCHANGE = @as(u32, 29);
pub const WM_TIMECHANGE = @as(u32, 30);
pub const WM_CANCELMODE = @as(u32, 31);
pub const WM_SETCURSOR = @as(u32, 32);
pub const WM_MOUSEACTIVATE = @as(u32, 33);
pub const WM_CHILDACTIVATE = @as(u32, 34);
pub const WM_QUEUESYNC = @as(u32, 35);
pub const WM_GETMINMAXINFO = @as(u32, 36);
pub const WM_PAINTICON = @as(u32, 38);
pub const WM_ICONERASEBKGND = @as(u32, 39);
pub const WM_NEXTDLGCTL = @as(u32, 40);
pub const WM_SPOOLERSTATUS = @as(u32, 42);
pub const WM_DRAWITEM = @as(u32, 43);
pub const WM_MEASUREITEM = @as(u32, 44);
pub const WM_DELETEITEM = @as(u32, 45);
pub const WM_VKEYTOITEM = @as(u32, 46);
pub const WM_CHARTOITEM = @as(u32, 47);
pub const WM_SETFONT = @as(u32, 48);
pub const WM_GETFONT = @as(u32, 49);
pub const WM_SETHOTKEY = @as(u32, 50);
pub const WM_GETHOTKEY = @as(u32, 51);
pub const WM_QUERYDRAGICON = @as(u32, 55);
pub const WM_COMPAREITEM = @as(u32, 57);
pub const WM_GETOBJECT = @as(u32, 61);
pub const WM_COMPACTING = @as(u32, 65);
pub const WM_COMMNOTIFY = @as(u32, 68);
pub const WM_WINDOWPOSCHANGING = @as(u32, 70);
pub const WM_WINDOWPOSCHANGED = @as(u32, 71);
pub const WM_POWER = @as(u32, 72);
pub const PWR_OK = @as(u32, 1);
pub const PWR_FAIL = @as(i32, -1);
pub const PWR_SUSPENDREQUEST = @as(u32, 1);
pub const PWR_SUSPENDRESUME = @as(u32, 2);
pub const PWR_CRITICALRESUME = @as(u32, 3);
pub const WM_COPYDATA = @as(u32, 74);
pub const WM_CANCELJOURNAL = @as(u32, 75);
pub const WM_INPUTLANGCHANGEREQUEST = @as(u32, 80);
pub const WM_INPUTLANGCHANGE = @as(u32, 81);
pub const WM_TCARD = @as(u32, 82);
pub const WM_HELP = @as(u32, 83);
pub const WM_USERCHANGED = @as(u32, 84);
pub const WM_NOTIFYFORMAT = @as(u32, 85);
pub const NFR_ANSI = @as(u32, 1);
pub const NFR_UNICODE = @as(u32, 2);
pub const NF_QUERY = @as(u32, 3);
pub const NF_REQUERY = @as(u32, 4);
pub const WM_STYLECHANGING = @as(u32, 124);
pub const WM_STYLECHANGED = @as(u32, 125);
pub const WM_DISPLAYCHANGE = @as(u32, 126);
pub const WM_GETICON = @as(u32, 127);
pub const WM_SETICON = @as(u32, 128);
pub const WM_NCCREATE = @as(u32, 129);
pub const WM_NCDESTROY = @as(u32, 130);
pub const WM_NCCALCSIZE = @as(u32, 131);
pub const WM_NCHITTEST = @as(u32, 132);
pub const WM_NCPAINT = @as(u32, 133);
pub const WM_NCACTIVATE = @as(u32, 134);
pub const WM_GETDLGCODE = @as(u32, 135);
pub const WM_SYNCPAINT = @as(u32, 136);
pub const WM_NCMOUSEMOVE = @as(u32, 160);
pub const WM_NCLBUTTONDOWN = @as(u32, 161);
pub const WM_NCLBUTTONUP = @as(u32, 162);
pub const WM_NCLBUTTONDBLCLK = @as(u32, 163);
pub const WM_NCRBUTTONDOWN = @as(u32, 164);
pub const WM_NCRBUTTONUP = @as(u32, 165);
pub const WM_NCRBUTTONDBLCLK = @as(u32, 166);
pub const WM_NCMBUTTONDOWN = @as(u32, 167);
pub const WM_NCMBUTTONUP = @as(u32, 168);
pub const WM_NCMBUTTONDBLCLK = @as(u32, 169);
pub const WM_NCXBUTTONDOWN = @as(u32, 171);
pub const WM_NCXBUTTONUP = @as(u32, 172);
pub const WM_NCXBUTTONDBLCLK = @as(u32, 173);
pub const WM_INPUT_DEVICE_CHANGE = @as(u32, 254);
pub const WM_INPUT = @as(u32, 255);
pub const WM_KEYFIRST = @as(u32, 256);
pub const WM_KEYDOWN = @as(u32, 256);
pub const WM_KEYUP = @as(u32, 257);
pub const WM_CHAR = @as(u32, 258);
pub const WM_DEADCHAR = @as(u32, 259);
pub const WM_SYSKEYDOWN = @as(u32, 260);
pub const WM_SYSKEYUP = @as(u32, 261);
pub const WM_SYSCHAR = @as(u32, 262);
pub const WM_SYSDEADCHAR = @as(u32, 263);
pub const WM_KEYLAST = @as(u32, 265);
pub const UNICODE_NOCHAR = @as(u32, 65535);
pub const WM_UNICHAR = @as(u32, 265);
pub const WM_IME_STARTCOMPOSITION = @as(u32, 269);
pub const WM_IME_ENDCOMPOSITION = @as(u32, 270);
pub const WM_IME_COMPOSITION = @as(u32, 271);
pub const WM_IME_KEYLAST = @as(u32, 271);
pub const WM_INITDIALOG = @as(u32, 272);
pub const WM_COMMAND = @as(u32, 273);
pub const WM_SYSCOMMAND = @as(u32, 274);
pub const WM_TIMER = @as(u32, 275);
pub const WM_HSCROLL = @as(u32, 276);
pub const WM_VSCROLL = @as(u32, 277);
pub const WM_INITMENU = @as(u32, 278);
pub const WM_INITMENUPOPUP = @as(u32, 279);
pub const WM_GESTURE = @as(u32, 281);
pub const WM_GESTURENOTIFY = @as(u32, 282);
pub const WM_MENUSELECT = @as(u32, 287);
pub const WM_MENUCHAR = @as(u32, 288);
pub const WM_ENTERIDLE = @as(u32, 289);
pub const WM_MENURBUTTONUP = @as(u32, 290);
pub const WM_MENUDRAG = @as(u32, 291);
pub const WM_MENUGETOBJECT = @as(u32, 292);
pub const WM_UNINITMENUPOPUP = @as(u32, 293);
pub const WM_MENUCOMMAND = @as(u32, 294);
pub const WM_CHANGEUISTATE = @as(u32, 295);
pub const WM_UPDATEUISTATE = @as(u32, 296);
pub const WM_QUERYUISTATE = @as(u32, 297);
pub const WM_MOUSELEAVE = @as(u32, 675);
pub const UIS_SET = @as(u32, 1);
pub const UIS_CLEAR = @as(u32, 2);
pub const UIS_INITIALIZE = @as(u32, 3);
pub const UISF_HIDEFOCUS = @as(u32, 1);
pub const UISF_HIDEACCEL = @as(u32, 2);
pub const UISF_ACTIVE = @as(u32, 4);
pub const WM_CTLCOLORMSGBOX = @as(u32, 306);
pub const WM_CTLCOLOREDIT = @as(u32, 307);
pub const WM_CTLCOLORLISTBOX = @as(u32, 308);
pub const WM_CTLCOLORBTN = @as(u32, 309);
pub const WM_CTLCOLORDLG = @as(u32, 310);
pub const WM_CTLCOLORSCROLLBAR = @as(u32, 311);
pub const WM_CTLCOLORSTATIC = @as(u32, 312);
pub const MN_GETHMENU = @as(u32, 481);
pub const WM_MOUSEFIRST = @as(u32, 512);
pub const WM_MOUSEMOVE = @as(u32, 512);
pub const WM_LBUTTONDOWN = @as(u32, 513);
pub const WM_LBUTTONUP = @as(u32, 514);
pub const WM_LBUTTONDBLCLK = @as(u32, 515);
pub const WM_RBUTTONDOWN = @as(u32, 516);
pub const WM_RBUTTONUP = @as(u32, 517);
pub const WM_RBUTTONDBLCLK = @as(u32, 518);
pub const WM_MBUTTONDOWN = @as(u32, 519);
pub const WM_MBUTTONUP = @as(u32, 520);
pub const WM_MBUTTONDBLCLK = @as(u32, 521);
pub const WM_MOUSEWHEEL = @as(u32, 522);
pub const WM_XBUTTONDOWN = @as(u32, 523);
pub const WM_XBUTTONUP = @as(u32, 524);
pub const WM_XBUTTONDBLCLK = @as(u32, 525);
pub const WM_MOUSEHWHEEL = @as(u32, 526);
pub const WM_MOUSELAST = @as(u32, 526);
pub const WHEEL_DELTA = @as(u32, 120);
pub const WM_PARENTNOTIFY = @as(u32, 528);
pub const WM_ENTERMENULOOP = @as(u32, 529);
pub const WM_EXITMENULOOP = @as(u32, 530);
pub const WM_NEXTMENU = @as(u32, 531);
pub const WM_SIZING = @as(u32, 532);
pub const WM_CAPTURECHANGED = @as(u32, 533);
pub const WM_MOVING = @as(u32, 534);
pub const WM_POWERBROADCAST = @as(u32, 536);
pub const PBT_APMQUERYSUSPEND = @as(u32, 0);
pub const PBT_APMQUERYSTANDBY = @as(u32, 1);
pub const PBT_APMQUERYSUSPENDFAILED = @as(u32, 2);
pub const PBT_APMQUERYSTANDBYFAILED = @as(u32, 3);
pub const PBT_APMSUSPEND = @as(u32, 4);
pub const PBT_APMSTANDBY = @as(u32, 5);
pub const PBT_APMRESUMECRITICAL = @as(u32, 6);
pub const PBT_APMRESUMESUSPEND = @as(u32, 7);
pub const PBT_APMRESUMESTANDBY = @as(u32, 8);
pub const PBTF_APMRESUMEFROMFAILURE = @as(u32, 1);
pub const PBT_APMBATTERYLOW = @as(u32, 9);
pub const PBT_APMPOWERSTATUSCHANGE = @as(u32, 10);
pub const PBT_APMOEMEVENT = @as(u32, 11);
pub const PBT_APMRESUMEAUTOMATIC = @as(u32, 18);
pub const PBT_POWERSETTINGCHANGE = @as(u32, 32787);
pub const WM_MDICREATE = @as(u32, 544);
pub const WM_MDIDESTROY = @as(u32, 545);
pub const WM_MDIACTIVATE = @as(u32, 546);
pub const WM_MDIRESTORE = @as(u32, 547);
pub const WM_MDINEXT = @as(u32, 548);
pub const WM_MDIMAXIMIZE = @as(u32, 549);
pub const WM_MDITILE = @as(u32, 550);
pub const WM_MDICASCADE = @as(u32, 551);
pub const WM_MDIICONARRANGE = @as(u32, 552);
pub const WM_MDIGETACTIVE = @as(u32, 553);
pub const WM_MDISETMENU = @as(u32, 560);
pub const WM_ENTERSIZEMOVE = @as(u32, 561);
pub const WM_EXITSIZEMOVE = @as(u32, 562);
pub const WM_DROPFILES = @as(u32, 563);
pub const WM_MDIREFRESHMENU = @as(u32, 564);
pub const WM_POINTERDEVICECHANGE = @as(u32, 568);
pub const WM_POINTERDEVICEINRANGE = @as(u32, 569);
pub const WM_POINTERDEVICEOUTOFRANGE = @as(u32, 570);
pub const WM_TOUCH = @as(u32, 576);
pub const WM_NCPOINTERUPDATE = @as(u32, 577);
pub const WM_NCPOINTERDOWN = @as(u32, 578);
pub const WM_NCPOINTERUP = @as(u32, 579);
pub const WM_POINTERUPDATE = @as(u32, 581);
pub const WM_POINTERDOWN = @as(u32, 582);
pub const WM_POINTERUP = @as(u32, 583);
pub const WM_POINTERENTER = @as(u32, 585);
pub const WM_POINTERLEAVE = @as(u32, 586);
pub const WM_POINTERACTIVATE = @as(u32, 587);
pub const WM_POINTERCAPTURECHANGED = @as(u32, 588);
pub const WM_TOUCHHITTESTING = @as(u32, 589);
pub const WM_POINTERWHEEL = @as(u32, 590);
pub const WM_POINTERHWHEEL = @as(u32, 591);
pub const DM_POINTERHITTEST = @as(u32, 592);
pub const WM_POINTERROUTEDTO = @as(u32, 593);
pub const WM_POINTERROUTEDAWAY = @as(u32, 594);
pub const WM_POINTERROUTEDRELEASED = @as(u32, 595);
pub const WM_IME_SETCONTEXT = @as(u32, 641);
pub const WM_IME_NOTIFY = @as(u32, 642);
pub const WM_IME_CONTROL = @as(u32, 643);
pub const WM_IME_COMPOSITIONFULL = @as(u32, 644);
pub const WM_IME_SELECT = @as(u32, 645);
pub const WM_IME_CHAR = @as(u32, 646);
pub const WM_IME_REQUEST = @as(u32, 648);
pub const WM_IME_KEYDOWN = @as(u32, 656);
pub const WM_IME_KEYUP = @as(u32, 657);
pub const WM_NCMOUSEHOVER = @as(u32, 672);
pub const WM_NCMOUSELEAVE = @as(u32, 674);
pub const WM_WTSSESSION_CHANGE = @as(u32, 689);
pub const WM_TABLET_FIRST = @as(u32, 704);
pub const WM_TABLET_LAST = @as(u32, 735);
pub const WM_DPICHANGED = @as(u32, 736);
pub const WM_DPICHANGED_BEFOREPARENT = @as(u32, 738);
pub const WM_DPICHANGED_AFTERPARENT = @as(u32, 739);
pub const WM_GETDPISCALEDSIZE = @as(u32, 740);
pub const WM_CUT = @as(u32, 768);
pub const WM_COPY = @as(u32, 769);
pub const WM_PASTE = @as(u32, 770);
pub const WM_CLEAR = @as(u32, 771);
pub const WM_UNDO = @as(u32, 772);
pub const WM_RENDERFORMAT = @as(u32, 773);
pub const WM_RENDERALLFORMATS = @as(u32, 774);
pub const WM_DESTROYCLIPBOARD = @as(u32, 775);
pub const WM_DRAWCLIPBOARD = @as(u32, 776);
pub const WM_PAINTCLIPBOARD = @as(u32, 777);
pub const WM_VSCROLLCLIPBOARD = @as(u32, 778);
pub const WM_SIZECLIPBOARD = @as(u32, 779);
pub const WM_ASKCBFORMATNAME = @as(u32, 780);
pub const WM_CHANGECBCHAIN = @as(u32, 781);
pub const WM_HSCROLLCLIPBOARD = @as(u32, 782);
pub const WM_QUERYNEWPALETTE = @as(u32, 783);
pub const WM_PALETTEISCHANGING = @as(u32, 784);
pub const WM_PALETTECHANGED = @as(u32, 785);
pub const WM_HOTKEY = @as(u32, 786);
pub const WM_PRINT = @as(u32, 791);
pub const WM_APPCOMMAND = @as(u32, 793);
pub const WM_THEMECHANGED = @as(u32, 794);
pub const WM_CLIPBOARDUPDATE = @as(u32, 797);
pub const WM_DWMCOMPOSITIONCHANGED = @as(u32, 798);
pub const WM_DWMNCRENDERINGCHANGED = @as(u32, 799);
pub const WM_DWMCOLORIZATIONCOLORCHANGED = @as(u32, 800);
pub const WM_DWMWINDOWMAXIMIZEDCHANGE = @as(u32, 801);
pub const WM_DWMSENDICONICTHUMBNAIL = @as(u32, 803);
pub const WM_DWMSENDICONICLIVEPREVIEWBITMAP = @as(u32, 806);
pub const WM_GETTITLEBARINFOEX = @as(u32, 831);
pub const WM_HANDHELDFIRST = @as(u32, 856);
pub const WM_HANDHELDLAST = @as(u32, 863);
pub const WM_AFXFIRST = @as(u32, 864);
pub const WM_AFXLAST = @as(u32, 895);
pub const WM_PENWINFIRST = @as(u32, 896);
pub const WM_PENWINLAST = @as(u32, 911);
pub const WM_APP = @as(u32, 32768);
pub const WM_USER = @as(u32, 1024);
pub const WMSZ_LEFT = @as(u32, 1);
pub const WMSZ_RIGHT = @as(u32, 2);
pub const WMSZ_TOP = @as(u32, 3);
pub const WMSZ_TOPLEFT = @as(u32, 4);
pub const WMSZ_TOPRIGHT = @as(u32, 5);
pub const WMSZ_BOTTOM = @as(u32, 6);
pub const WMSZ_BOTTOMLEFT = @as(u32, 7);
pub const WMSZ_BOTTOMRIGHT = @as(u32, 8);
pub const HTERROR = @as(i32, -2);
pub const HTTRANSPARENT = @as(i32, -1);
pub const HTNOWHERE = @as(u32, 0);
pub const HTCLIENT = @as(u32, 1);
pub const HTCAPTION = @as(u32, 2);
pub const HTSYSMENU = @as(u32, 3);
pub const HTGROWBOX = @as(u32, 4);
pub const HTSIZE = @as(u32, 4);
pub const HTMENU = @as(u32, 5);
pub const HTHSCROLL = @as(u32, 6);
pub const HTVSCROLL = @as(u32, 7);
pub const HTMINBUTTON = @as(u32, 8);
pub const HTMAXBUTTON = @as(u32, 9);
pub const HTLEFT = @as(u32, 10);
pub const HTRIGHT = @as(u32, 11);
pub const HTTOP = @as(u32, 12);
pub const HTTOPLEFT = @as(u32, 13);
pub const HTTOPRIGHT = @as(u32, 14);
pub const HTBOTTOM = @as(u32, 15);
pub const HTBOTTOMLEFT = @as(u32, 16);
pub const HTBOTTOMRIGHT = @as(u32, 17);
pub const HTBORDER = @as(u32, 18);
pub const HTREDUCE = @as(u32, 8);
pub const HTZOOM = @as(u32, 9);
pub const HTSIZEFIRST = @as(u32, 10);
pub const HTSIZELAST = @as(u32, 17);
pub const HTOBJECT = @as(u32, 19);
pub const HTCLOSE = @as(u32, 20);
pub const HTHELP = @as(u32, 21);
pub const MA_ACTIVATE = @as(u32, 1);
pub const MA_ACTIVATEANDEAT = @as(u32, 2);
pub const MA_NOACTIVATE = @as(u32, 3);
pub const MA_NOACTIVATEANDEAT = @as(u32, 4);
pub const ICON_SMALL = @as(u32, 0);
pub const ICON_BIG = @as(u32, 1);
pub const ICON_SMALL2 = @as(u32, 2);
pub const SIZE_RESTORED = @as(u32, 0);
pub const SIZE_MINIMIZED = @as(u32, 1);
pub const SIZE_MAXIMIZED = @as(u32, 2);
pub const SIZE_MAXSHOW = @as(u32, 3);
pub const SIZE_MAXHIDE = @as(u32, 4);
pub const HWND_BOTTOM = @as(win32.HWND, @ptrFromInt(@as(u32, @bitCast(@as(i32, 1)))));
pub const HWND_TOPMOST = @as(win32.HWND, @ptrFromInt(@as(u32, @bitCast(@as(i32, -1)))));
pub const HWND_NOTOPMOST = @as(win32.HWND, @ptrFromInt(@as(u32, @bitCast(@as(i32, -2)))));

//===================
// Types
//===================
pub const SET_WINDOW_POS_FLAGS = packed struct(u32) {
    NOSIZE: u1 = 0,
    NOMOVE: u1 = 0,
    NOZORDER: u1 = 0,
    NOREDRAW: u1 = 0,
    NOACTIVATE: u1 = 0,
    DRAWFRAME: u1 = 0,
    SHOWWINDOW: u1 = 0,
    HIDEWINDOW: u1 = 0,
    NOCOPYBITS: u1 = 0,
    NOOWNERZORDER: u1 = 0,
    NOSENDCHANGING: u1 = 0,
    _11: u1 = 0,
    _12: u1 = 0,
    DEFERERASE: u1 = 0,
    ASYNCWINDOWPOS: u1 = 0,
    _15: u1 = 0,
    _16: u1 = 0,
    _17: u1 = 0,
    _18: u1 = 0,
    _19: u1 = 0,
    _20: u1 = 0,
    _21: u1 = 0,
    _22: u1 = 0,
    _23: u1 = 0,
    _24: u1 = 0,
    _25: u1 = 0,
    _26: u1 = 0,
    _27: u1 = 0,
    _28: u1 = 0,
    _29: u1 = 0,
    _30: u1 = 0,
    _31: u1 = 0,
    // FRAMECHANGED (bit index 5) conflicts with DRAWFRAME
    // NOREPOSITION (bit index 9) conflicts with NOOWNERZORDER
};
pub const SWP_ASYNCWINDOWPOS = SET_WINDOW_POS_FLAGS{ .ASYNCWINDOWPOS = 1 };
pub const SWP_DEFERERASE = SET_WINDOW_POS_FLAGS{ .DEFERERASE = 1 };
pub const SWP_DRAWFRAME = SET_WINDOW_POS_FLAGS{ .DRAWFRAME = 1 };
pub const SWP_FRAMECHANGED = SET_WINDOW_POS_FLAGS{ .DRAWFRAME = 1 };
pub const SWP_HIDEWINDOW = SET_WINDOW_POS_FLAGS{ .HIDEWINDOW = 1 };
pub const SWP_NOACTIVATE = SET_WINDOW_POS_FLAGS{ .NOACTIVATE = 1 };
pub const SWP_NOCOPYBITS = SET_WINDOW_POS_FLAGS{ .NOCOPYBITS = 1 };
pub const SWP_NOMOVE = SET_WINDOW_POS_FLAGS{ .NOMOVE = 1 };
pub const SWP_NOOWNERZORDER = SET_WINDOW_POS_FLAGS{ .NOOWNERZORDER = 1 };
pub const SWP_NOREDRAW = SET_WINDOW_POS_FLAGS{ .NOREDRAW = 1 };
pub const SWP_NOREPOSITION = SET_WINDOW_POS_FLAGS{ .NOOWNERZORDER = 1 };
pub const SWP_NOSENDCHANGING = SET_WINDOW_POS_FLAGS{ .NOSENDCHANGING = 1 };
pub const SWP_NOSIZE = SET_WINDOW_POS_FLAGS{ .NOSIZE = 1 };
pub const SWP_NOZORDER = SET_WINDOW_POS_FLAGS{ .NOZORDER = 1 };
pub const SWP_SHOWWINDOW = SET_WINDOW_POS_FLAGS{ .SHOWWINDOW = 1 };

pub const SYSTEM_METRICS_INDEX = enum(u32) {
    ARRANGE = 56,
    CLEANBOOT = 67,
    CMONITORS = 80,
    CMOUSEBUTTONS = 43,
    CONVERTIBLESLATEMODE = 8195,
    CXBORDER = 5,
    CXCURSOR = 13,
    CXDLGFRAME = 7,
    CXDOUBLECLK = 36,
    CXDRAG = 68,
    CXEDGE = 45,
    // CXFIXEDFRAME = 7, this enum value conflicts with CXDLGFRAME
    CXFOCUSBORDER = 83,
    CXFRAME = 32,
    CXFULLSCREEN = 16,
    CXHSCROLL = 21,
    CXHTHUMB = 10,
    CXICON = 11,
    CXICONSPACING = 38,
    CXMAXIMIZED = 61,
    CXMAXTRACK = 59,
    CXMENUCHECK = 71,
    CXMENUSIZE = 54,
    CXMIN = 28,
    CXMINIMIZED = 57,
    CXMINSPACING = 47,
    CXMINTRACK = 34,
    CXPADDEDBORDER = 92,
    CXSCREEN = 0,
    CXSIZE = 30,
    // CXSIZEFRAME = 32, this enum value conflicts with CXFRAME
    CXSMICON = 49,
    CXSMSIZE = 52,
    CXVIRTUALSCREEN = 78,
    CXVSCROLL = 2,
    CYBORDER = 6,
    CYCAPTION = 4,
    CYCURSOR = 14,
    CYDLGFRAME = 8,
    CYDOUBLECLK = 37,
    CYDRAG = 69,
    CYEDGE = 46,
    // CYFIXEDFRAME = 8, this enum value conflicts with CYDLGFRAME
    CYFOCUSBORDER = 84,
    CYFRAME = 33,
    CYFULLSCREEN = 17,
    CYHSCROLL = 3,
    CYICON = 12,
    CYICONSPACING = 39,
    CYKANJIWINDOW = 18,
    CYMAXIMIZED = 62,
    CYMAXTRACK = 60,
    CYMENU = 15,
    CYMENUCHECK = 72,
    CYMENUSIZE = 55,
    CYMIN = 29,
    CYMINIMIZED = 58,
    CYMINSPACING = 48,
    CYMINTRACK = 35,
    CYSCREEN = 1,
    CYSIZE = 31,
    // CYSIZEFRAME = 33, this enum value conflicts with CYFRAME
    CYSMCAPTION = 51,
    CYSMICON = 50,
    CYSMSIZE = 53,
    CYVIRTUALSCREEN = 79,
    CYVSCROLL = 20,
    CYVTHUMB = 9,
    DBCSENABLED = 42,
    DEBUG = 22,
    DIGITIZER = 94,
    IMMENABLED = 82,
    MAXIMUMTOUCHES = 95,
    MEDIACENTER = 87,
    MENUDROPALIGNMENT = 40,
    MIDEASTENABLED = 74,
    MOUSEPRESENT = 19,
    MOUSEHORIZONTALWHEELPRESENT = 91,
    MOUSEWHEELPRESENT = 75,
    NETWORK = 63,
    PENWINDOWS = 41,
    REMOTECONTROL = 8193,
    REMOTESESSION = 4096,
    SAMEDISPLAYFORMAT = 81,
    SECURE = 44,
    SERVERR2 = 89,
    SHOWSOUNDS = 70,
    SHUTTINGDOWN = 8192,
    SLOWMACHINE = 73,
    STARTER = 88,
    SWAPBUTTON = 23,
    SYSTEMDOCKED = 8196,
    TABLETPC = 86,
    XVIRTUALSCREEN = 76,
    YVIRTUALSCREEN = 77,
};
pub const SM_ARRANGE = SYSTEM_METRICS_INDEX.ARRANGE;
pub const SM_CLEANBOOT = SYSTEM_METRICS_INDEX.CLEANBOOT;
pub const SM_CMONITORS = SYSTEM_METRICS_INDEX.CMONITORS;
pub const SM_CMOUSEBUTTONS = SYSTEM_METRICS_INDEX.CMOUSEBUTTONS;
pub const SM_CONVERTIBLESLATEMODE = SYSTEM_METRICS_INDEX.CONVERTIBLESLATEMODE;
pub const SM_CXBORDER = SYSTEM_METRICS_INDEX.CXBORDER;
pub const SM_CXCURSOR = SYSTEM_METRICS_INDEX.CXCURSOR;
pub const SM_CXDLGFRAME = SYSTEM_METRICS_INDEX.CXDLGFRAME;
pub const SM_CXDOUBLECLK = SYSTEM_METRICS_INDEX.CXDOUBLECLK;
pub const SM_CXDRAG = SYSTEM_METRICS_INDEX.CXDRAG;
pub const SM_CXEDGE = SYSTEM_METRICS_INDEX.CXEDGE;
pub const SM_CXFIXEDFRAME = SYSTEM_METRICS_INDEX.CXDLGFRAME;
pub const SM_CXFOCUSBORDER = SYSTEM_METRICS_INDEX.CXFOCUSBORDER;
pub const SM_CXFRAME = SYSTEM_METRICS_INDEX.CXFRAME;
pub const SM_CXFULLSCREEN = SYSTEM_METRICS_INDEX.CXFULLSCREEN;
pub const SM_CXHSCROLL = SYSTEM_METRICS_INDEX.CXHSCROLL;
pub const SM_CXHTHUMB = SYSTEM_METRICS_INDEX.CXHTHUMB;
pub const SM_CXICON = SYSTEM_METRICS_INDEX.CXICON;
pub const SM_CXICONSPACING = SYSTEM_METRICS_INDEX.CXICONSPACING;
pub const SM_CXMAXIMIZED = SYSTEM_METRICS_INDEX.CXMAXIMIZED;
pub const SM_CXMAXTRACK = SYSTEM_METRICS_INDEX.CXMAXTRACK;
pub const SM_CXMENUCHECK = SYSTEM_METRICS_INDEX.CXMENUCHECK;
pub const SM_CXMENUSIZE = SYSTEM_METRICS_INDEX.CXMENUSIZE;
pub const SM_CXMIN = SYSTEM_METRICS_INDEX.CXMIN;
pub const SM_CXMINIMIZED = SYSTEM_METRICS_INDEX.CXMINIMIZED;
pub const SM_CXMINSPACING = SYSTEM_METRICS_INDEX.CXMINSPACING;
pub const SM_CXMINTRACK = SYSTEM_METRICS_INDEX.CXMINTRACK;
pub const SM_CXPADDEDBORDER = SYSTEM_METRICS_INDEX.CXPADDEDBORDER;
pub const SM_CXSCREEN = SYSTEM_METRICS_INDEX.CXSCREEN;
pub const SM_CXSIZE = SYSTEM_METRICS_INDEX.CXSIZE;
pub const SM_CXSIZEFRAME = SYSTEM_METRICS_INDEX.CXFRAME;
pub const SM_CXSMICON = SYSTEM_METRICS_INDEX.CXSMICON;
pub const SM_CXSMSIZE = SYSTEM_METRICS_INDEX.CXSMSIZE;
pub const SM_CXVIRTUALSCREEN = SYSTEM_METRICS_INDEX.CXVIRTUALSCREEN;
pub const SM_CXVSCROLL = SYSTEM_METRICS_INDEX.CXVSCROLL;
pub const SM_CYBORDER = SYSTEM_METRICS_INDEX.CYBORDER;
pub const SM_CYCAPTION = SYSTEM_METRICS_INDEX.CYCAPTION;
pub const SM_CYCURSOR = SYSTEM_METRICS_INDEX.CYCURSOR;
pub const SM_CYDLGFRAME = SYSTEM_METRICS_INDEX.CYDLGFRAME;
pub const SM_CYDOUBLECLK = SYSTEM_METRICS_INDEX.CYDOUBLECLK;
pub const SM_CYDRAG = SYSTEM_METRICS_INDEX.CYDRAG;
pub const SM_CYEDGE = SYSTEM_METRICS_INDEX.CYEDGE;
pub const SM_CYFIXEDFRAME = SYSTEM_METRICS_INDEX.CYDLGFRAME;
pub const SM_CYFOCUSBORDER = SYSTEM_METRICS_INDEX.CYFOCUSBORDER;
pub const SM_CYFRAME = SYSTEM_METRICS_INDEX.CYFRAME;
pub const SM_CYFULLSCREEN = SYSTEM_METRICS_INDEX.CYFULLSCREEN;
pub const SM_CYHSCROLL = SYSTEM_METRICS_INDEX.CYHSCROLL;
pub const SM_CYICON = SYSTEM_METRICS_INDEX.CYICON;
pub const SM_CYICONSPACING = SYSTEM_METRICS_INDEX.CYICONSPACING;
pub const SM_CYKANJIWINDOW = SYSTEM_METRICS_INDEX.CYKANJIWINDOW;
pub const SM_CYMAXIMIZED = SYSTEM_METRICS_INDEX.CYMAXIMIZED;
pub const SM_CYMAXTRACK = SYSTEM_METRICS_INDEX.CYMAXTRACK;
pub const SM_CYMENU = SYSTEM_METRICS_INDEX.CYMENU;
pub const SM_CYMENUCHECK = SYSTEM_METRICS_INDEX.CYMENUCHECK;
pub const SM_CYMENUSIZE = SYSTEM_METRICS_INDEX.CYMENUSIZE;
pub const SM_CYMIN = SYSTEM_METRICS_INDEX.CYMIN;
pub const SM_CYMINIMIZED = SYSTEM_METRICS_INDEX.CYMINIMIZED;
pub const SM_CYMINSPACING = SYSTEM_METRICS_INDEX.CYMINSPACING;
pub const SM_CYMINTRACK = SYSTEM_METRICS_INDEX.CYMINTRACK;
pub const SM_CYSCREEN = SYSTEM_METRICS_INDEX.CYSCREEN;
pub const SM_CYSIZE = SYSTEM_METRICS_INDEX.CYSIZE;
pub const SM_CYSIZEFRAME = SYSTEM_METRICS_INDEX.CYFRAME;
pub const SM_CYSMCAPTION = SYSTEM_METRICS_INDEX.CYSMCAPTION;
pub const SM_CYSMICON = SYSTEM_METRICS_INDEX.CYSMICON;
pub const SM_CYSMSIZE = SYSTEM_METRICS_INDEX.CYSMSIZE;
pub const SM_CYVIRTUALSCREEN = SYSTEM_METRICS_INDEX.CYVIRTUALSCREEN;
pub const SM_CYVSCROLL = SYSTEM_METRICS_INDEX.CYVSCROLL;
pub const SM_CYVTHUMB = SYSTEM_METRICS_INDEX.CYVTHUMB;
pub const SM_DBCSENABLED = SYSTEM_METRICS_INDEX.DBCSENABLED;
pub const SM_DEBUG = SYSTEM_METRICS_INDEX.DEBUG;
pub const SM_DIGITIZER = SYSTEM_METRICS_INDEX.DIGITIZER;
pub const SM_IMMENABLED = SYSTEM_METRICS_INDEX.IMMENABLED;
pub const SM_MAXIMUMTOUCHES = SYSTEM_METRICS_INDEX.MAXIMUMTOUCHES;
pub const SM_MEDIACENTER = SYSTEM_METRICS_INDEX.MEDIACENTER;
pub const SM_MENUDROPALIGNMENT = SYSTEM_METRICS_INDEX.MENUDROPALIGNMENT;
pub const SM_MIDEASTENABLED = SYSTEM_METRICS_INDEX.MIDEASTENABLED;
pub const SM_MOUSEPRESENT = SYSTEM_METRICS_INDEX.MOUSEPRESENT;
pub const SM_MOUSEHORIZONTALWHEELPRESENT = SYSTEM_METRICS_INDEX.MOUSEHORIZONTALWHEELPRESENT;
pub const SM_MOUSEWHEELPRESENT = SYSTEM_METRICS_INDEX.MOUSEWHEELPRESENT;
pub const SM_NETWORK = SYSTEM_METRICS_INDEX.NETWORK;
pub const SM_PENWINDOWS = SYSTEM_METRICS_INDEX.PENWINDOWS;
pub const SM_REMOTECONTROL = SYSTEM_METRICS_INDEX.REMOTECONTROL;
pub const SM_REMOTESESSION = SYSTEM_METRICS_INDEX.REMOTESESSION;
pub const SM_SAMEDISPLAYFORMAT = SYSTEM_METRICS_INDEX.SAMEDISPLAYFORMAT;
pub const SM_SECURE = SYSTEM_METRICS_INDEX.SECURE;
pub const SM_SERVERR2 = SYSTEM_METRICS_INDEX.SERVERR2;
pub const SM_SHOWSOUNDS = SYSTEM_METRICS_INDEX.SHOWSOUNDS;
pub const SM_SHUTTINGDOWN = SYSTEM_METRICS_INDEX.SHUTTINGDOWN;
pub const SM_SLOWMACHINE = SYSTEM_METRICS_INDEX.SLOWMACHINE;
pub const SM_STARTER = SYSTEM_METRICS_INDEX.STARTER;
pub const SM_SWAPBUTTON = SYSTEM_METRICS_INDEX.SWAPBUTTON;
pub const SM_SYSTEMDOCKED = SYSTEM_METRICS_INDEX.SYSTEMDOCKED;
pub const SM_TABLETPC = SYSTEM_METRICS_INDEX.TABLETPC;
pub const SM_XVIRTUALSCREEN = SYSTEM_METRICS_INDEX.XVIRTUALSCREEN;
pub const SM_YVIRTUALSCREEN = SYSTEM_METRICS_INDEX.YVIRTUALSCREEN;

pub const PEEK_MESSAGE_REMOVE_TYPE = packed struct(u32) {
    REMOVE: u1 = 0,
    NOYIELD: u1 = 0,
    _2: u1 = 0,
    _3: u1 = 0,
    _4: u1 = 0,
    _5: u1 = 0,
    _6: u1 = 0,
    _7: u1 = 0,
    _8: u1 = 0,
    _9: u1 = 0,
    _10: u1 = 0,
    _11: u1 = 0,
    _12: u1 = 0,
    _13: u1 = 0,
    _14: u1 = 0,
    _15: u1 = 0,
    _16: u1 = 0,
    _17: u1 = 0,
    _18: u1 = 0,
    _19: u1 = 0,
    _20: u1 = 0,
    QS_PAINT: u1 = 0,
    QS_SENDMESSAGE: u1 = 0,
    _23: u1 = 0,
    _24: u1 = 0,
    _25: u1 = 0,
    _26: u1 = 0,
    _27: u1 = 0,
    _28: u1 = 0,
    _29: u1 = 0,
    _30: u1 = 0,
    _31: u1 = 0,
};
pub const PM_NOREMOVE = PEEK_MESSAGE_REMOVE_TYPE{};
pub const PM_REMOVE = PEEK_MESSAGE_REMOVE_TYPE{ .REMOVE = 1 };
pub const PM_NOYIELD = PEEK_MESSAGE_REMOVE_TYPE{ .NOYIELD = 1 };
pub const PM_QS_INPUT = PEEK_MESSAGE_REMOVE_TYPE{
    ._16 = 1,
    ._17 = 1,
    ._18 = 1,
    ._26 = 1,
};
pub const PM_QS_POSTMESSAGE = PEEK_MESSAGE_REMOVE_TYPE{
    ._19 = 1,
    ._20 = 1,
    ._23 = 1,
};
pub const PM_QS_PAINT = PEEK_MESSAGE_REMOVE_TYPE{ .QS_PAINT = 1 };
pub const PM_QS_SENDMESSAGE = PEEK_MESSAGE_REMOVE_TYPE{ .QS_SENDMESSAGE = 1 };

pub const MSG = extern struct {
    hwnd: ?win32.HWND,
    message: u32,
    wParam: win32.WPARAM,
    lParam: win32.LPARAM,
    time: u32,
    pt: win32.POINT,
};

pub const MINMAXINFO = extern struct {
    ptReserved: win32.POINT,
    ptMaxSize: win32.POINT,
    ptMaxPosition: win32.POINT,
    ptMinTrackSize: win32.POINT,
    ptMaxTrackSize: win32.POINT,
};

pub const SIZE = extern struct {
    cx: i32,
    cy: i32,
};

pub const WINDOW_MESSAGE_FILTER_ACTION = enum(u32) {
    ALLOW = 1,
    DISALLOW = 2,
    RESET = 0,
};
pub const MSGFLT_ALLOW = WINDOW_MESSAGE_FILTER_ACTION.ALLOW;
pub const MSGFLT_DISALLOW = WINDOW_MESSAGE_FILTER_ACTION.DISALLOW;
pub const MSGFLT_RESET = WINDOW_MESSAGE_FILTER_ACTION.RESET;

pub const MSGFLTINFO_STATUS = enum(u32) {
    NONE = 0,
    ALLOWED_HIGHER = 3,
    ALREADYALLOWED_FORWND = 1,
    ALREADYDISALLOWED_FORWND = 2,
};
pub const MSGFLTINFO_NONE = MSGFLTINFO_STATUS.NONE;
pub const MSGFLTINFO_ALLOWED_HIGHER = MSGFLTINFO_STATUS.ALLOWED_HIGHER;
pub const MSGFLTINFO_ALREADYALLOWED_FORWND = MSGFLTINFO_STATUS.ALREADYALLOWED_FORWND;
pub const MSGFLTINFO_ALREADYDISALLOWED_FORWND = MSGFLTINFO_STATUS.ALREADYDISALLOWED_FORWND;

pub const CHANGEFILTERSTRUCT = extern struct {
    cbSize: u32,
    ExtStatus: MSGFLTINFO_STATUS,
};

pub const QUEUE_STATUS_FLAGS = packed struct(u32) {
    KEY: u1 = 0,
    MOUSEMOVE: u1 = 0,
    MOUSEBUTTON: u1 = 0,
    POSTMESSAGE: u1 = 0,
    TIMER: u1 = 0,
    PAINT: u1 = 0,
    SENDMESSAGE: u1 = 0,
    HOTKEY: u1 = 0,
    ALLPOSTMESSAGE: u1 = 0,
    _9: u1 = 0,
    RAWINPUT: u1 = 0,
    _11: u1 = 0,
    _12: u1 = 0,
    _13: u1 = 0,
    _14: u1 = 0,
    _15: u1 = 0,
    _16: u1 = 0,
    _17: u1 = 0,
    _18: u1 = 0,
    _19: u1 = 0,
    _20: u1 = 0,
    _21: u1 = 0,
    _22: u1 = 0,
    _23: u1 = 0,
    _24: u1 = 0,
    _25: u1 = 0,
    _26: u1 = 0,
    _27: u1 = 0,
    _28: u1 = 0,
    _29: u1 = 0,
    _30: u1 = 0,
    _31: u1 = 0,
};
pub const QS_ALLEVENTS = QUEUE_STATUS_FLAGS{
    .KEY = 1,
    .MOUSEMOVE = 1,
    .MOUSEBUTTON = 1,
    .POSTMESSAGE = 1,
    .TIMER = 1,
    .PAINT = 1,
    .HOTKEY = 1,
    .RAWINPUT = 1,
};
pub const QS_ALLINPUT = QUEUE_STATUS_FLAGS{
    .KEY = 1,
    .MOUSEMOVE = 1,
    .MOUSEBUTTON = 1,
    .POSTMESSAGE = 1,
    .TIMER = 1,
    .PAINT = 1,
    .SENDMESSAGE = 1,
    .HOTKEY = 1,
    .RAWINPUT = 1,
};
pub const QS_ALLPOSTMESSAGE = QUEUE_STATUS_FLAGS{ .ALLPOSTMESSAGE = 1 };
pub const QS_HOTKEY = QUEUE_STATUS_FLAGS{ .HOTKEY = 1 };
pub const QS_INPUT = QUEUE_STATUS_FLAGS{
    .KEY = 1,
    .MOUSEMOVE = 1,
    .MOUSEBUTTON = 1,
    .RAWINPUT = 1,
};
pub const QS_KEY = QUEUE_STATUS_FLAGS{ .KEY = 1 };
pub const QS_MOUSE = QUEUE_STATUS_FLAGS{
    .MOUSEMOVE = 1,
    .MOUSEBUTTON = 1,
};
pub const QS_MOUSEBUTTON = QUEUE_STATUS_FLAGS{ .MOUSEBUTTON = 1 };
pub const QS_MOUSEMOVE = QUEUE_STATUS_FLAGS{ .MOUSEMOVE = 1 };
pub const QS_PAINT = QUEUE_STATUS_FLAGS{ .PAINT = 1 };
pub const QS_POSTMESSAGE = QUEUE_STATUS_FLAGS{ .POSTMESSAGE = 1 };
pub const QS_RAWINPUT = QUEUE_STATUS_FLAGS{ .RAWINPUT = 1 };
pub const QS_SENDMESSAGE = QUEUE_STATUS_FLAGS{ .SENDMESSAGE = 1 };
pub const QS_TIMER = QUEUE_STATUS_FLAGS{ .TIMER = 1 };

pub const FLASHWINFO_FLAGS = packed struct(u32) {
    CAPTION: u1 = 0,
    TRAY: u1 = 0,
    TIMER: u1 = 0,
    _3: u1 = 0,
    _4: u1 = 0,
    _5: u1 = 0,
    _6: u1 = 0,
    _7: u1 = 0,
    _8: u1 = 0,
    _9: u1 = 0,
    _10: u1 = 0,
    _11: u1 = 0,
    _12: u1 = 0,
    _13: u1 = 0,
    _14: u1 = 0,
    _15: u1 = 0,
    _16: u1 = 0,
    _17: u1 = 0,
    _18: u1 = 0,
    _19: u1 = 0,
    _20: u1 = 0,
    _21: u1 = 0,
    _22: u1 = 0,
    _23: u1 = 0,
    _24: u1 = 0,
    _25: u1 = 0,
    _26: u1 = 0,
    _27: u1 = 0,
    _28: u1 = 0,
    _29: u1 = 0,
    _30: u1 = 0,
    _31: u1 = 0,
};
pub const FLASHW_ALL = FLASHWINFO_FLAGS{
    .CAPTION = 1,
    .TRAY = 1,
};
pub const FLASHW_CAPTION = FLASHWINFO_FLAGS{ .CAPTION = 1 };
pub const FLASHW_STOP = FLASHWINFO_FLAGS{};
pub const FLASHW_TIMER = FLASHWINFO_FLAGS{ .TIMER = 1 };
pub const FLASHW_TIMERNOFG = FLASHWINFO_FLAGS{
    .TIMER = 1,
    ._3 = 1,
};
pub const FLASHW_TRAY = FLASHWINFO_FLAGS{ .TRAY = 1 };

pub const FLASHWINFO = extern struct {
    cbSize: u32,
    hwnd: ?win32.HWND,
    dwFlags: FLASHWINFO_FLAGS,
    uCount: u32,
    dwTimeout: u32,
};

pub const GET_CLASS_LONG_INDEX = enum(i32) {
    W_ATOM = -32,
    L_CBCLSEXTRA = -20,
    L_CBWNDEXTRA = -18,
    L_HBRBACKGROUND = -10,
    L_HCURSOR = -12,
    L_HICON = -14,
    L_HICONSM = -34,
    L_HMODULE = -16,
    L_MENUNAME = -8,
    L_STYLE = -26,
    L_WNDPROC = -24,
    // LP_HBRBACKGROUND = -10, this enum value conflicts with L_HBRBACKGROUND
    // LP_HCURSOR = -12, this enum value conflicts with L_HCURSOR
    // LP_HICON = -14, this enum value conflicts with L_HICON
    // LP_HICONSM = -34, this enum value conflicts with L_HICONSM
    // LP_HMODULE = -16, this enum value conflicts with L_HMODULE
    // LP_MENUNAME = -8, this enum value conflicts with L_MENUNAME
    // LP_WNDPROC = -24, this enum value conflicts with L_WNDPROC
};
pub const GCW_ATOM = GET_CLASS_LONG_INDEX.W_ATOM;
pub const GCL_CBCLSEXTRA = GET_CLASS_LONG_INDEX.L_CBCLSEXTRA;
pub const GCL_CBWNDEXTRA = GET_CLASS_LONG_INDEX.L_CBWNDEXTRA;
pub const GCL_HBRBACKGROUND = GET_CLASS_LONG_INDEX.L_HBRBACKGROUND;
pub const GCL_HCURSOR = GET_CLASS_LONG_INDEX.L_HCURSOR;
pub const GCL_HICON = GET_CLASS_LONG_INDEX.L_HICON;
pub const GCL_HICONSM = GET_CLASS_LONG_INDEX.L_HICONSM;
pub const GCL_HMODULE = GET_CLASS_LONG_INDEX.L_HMODULE;
pub const GCL_MENUNAME = GET_CLASS_LONG_INDEX.L_MENUNAME;
pub const GCL_STYLE = GET_CLASS_LONG_INDEX.L_STYLE;
pub const GCL_WNDPROC = GET_CLASS_LONG_INDEX.L_WNDPROC;
pub const GCLP_HBRBACKGROUND = GET_CLASS_LONG_INDEX.L_HBRBACKGROUND;
pub const GCLP_HCURSOR = GET_CLASS_LONG_INDEX.L_HCURSOR;
pub const GCLP_HICON = GET_CLASS_LONG_INDEX.L_HICON;
pub const GCLP_HICONSM = GET_CLASS_LONG_INDEX.L_HICONSM;
pub const GCLP_HMODULE = GET_CLASS_LONG_INDEX.L_HMODULE;
pub const GCLP_MENUNAME = GET_CLASS_LONG_INDEX.L_MENUNAME;
pub const GCLP_WNDPROC = GET_CLASS_LONG_INDEX.L_WNDPROC;

//==========================
// Functions
//=========================
pub extern "user32" fn SetWindowPos(
    hWnd: ?win32.HWND,
    hWndInsertAfter: ?win32.HWND,
    X: i32,
    Y: i32,
    cx: i32,
    cy: i32,
    uFlags: SET_WINDOW_POS_FLAGS,
) callconv(win32.WINAPI) win32.BOOL;

pub extern "user32" fn IsIconic(
    hWnd: ?win32.HWND,
) callconv(win32.WINAPI) win32.BOOL;

pub extern "user32" fn GetSystemMetrics(
    nIndex: SYSTEM_METRICS_INDEX,
) callconv(win32.WINAPI) i32;

pub extern "user32" fn DefWindowProcW(
    hWnd: ?win32.HWND,
    Msg: u32,
    wParam: win32.WPARAM,
    lParam: win32.LPARAM,
) callconv(win32.WINAPI) win32.LRESULT;

pub extern "user32" fn GetMessageTime() callconv(win32.WINAPI) i32;

pub extern "user32" fn PeekMessageW(
    lpMsg: ?*MSG,
    hWnd: ?win32.HWND,
    wMsgFilterMin: u32,
    wMsgFilterMax: u32,
    wRemoveMsg: PEEK_MESSAGE_REMOVE_TYPE,
) callconv(win32.WINAPI) win32.BOOL;

pub extern "user32" fn GetWindowRect(
    hWnd: ?win32.HWND,
    lpRect: ?*win32.RECT,
) callconv(win32.WINAPI) win32.BOOL;

pub extern "user32" fn GetClientRect(
    hWnd: ?win32.HWND,
    lpRect: ?*win32.RECT,
) callconv(win32.WINAPI) win32.BOOL;

pub extern "user32" fn ClipCursor(
    lpRect: ?*const win32.RECT,
) callconv(win32.WINAPI) win32.BOOL;

pub extern "user32" fn SetCursorPos(
    X: i32,
    Y: i32,
) callconv(win32.WINAPI) win32.BOOL;

pub extern "user32" fn GetCursorPos(
    lpPoint: ?*win32.POINT,
) callconv(win32.WINAPI) win32.BOOL;

pub extern "user32" fn ChangeWindowMessageFilterEx(
    hwnd: ?win32.HWND,
    message: u32,
    action: WINDOW_MESSAGE_FILTER_ACTION,
    pChangeFilterStruct: ?*CHANGEFILTERSTRUCT,
) callconv(win32.WINAPI) win32.BOOL;

pub extern "user32" fn TranslateMessage(
    lpMsg: ?*const MSG,
) callconv(win32.WINAPI) win32.BOOL;

pub extern "user32" fn DispatchMessageW(
    lpMsg: ?*const MSG,
) callconv(win32.WINAPI) win32.LRESULT;

pub extern "user32" fn WaitMessage() callconv(win32.WINAPI) win32.LRESULT;

pub extern "user32" fn MsgWaitForMultipleObjects(
    nCount: u32,
    pHandles: ?[*]const ?win32.HANDLE,
    fWaitAll: win32.BOOL,
    dwMilliseconds: u32,
    dwWakeMask: QUEUE_STATUS_FLAGS,
) callconv(win32.WINAPI) u32;

pub extern "user32" fn FlashWindowEx(
    pfwi: ?*FLASHWINFO,
) callconv(win32.WINAPI) win32.BOOL;

pub extern "user32" fn SendMessageW(
    hWnd: ?win32.HWND,
    Msg: u32,
    wParam: win32.WPARAM,
    lParam: win32.LPARAM,
) callconv(win32.WINAPI) win32.LRESULT;

pub extern "user32" fn GetClassLongPtrW(
    hWnd: ?win32.HWND,
    nIndex: GET_CLASS_LONG_INDEX,
) callconv(win32.WINAPI) usize;
