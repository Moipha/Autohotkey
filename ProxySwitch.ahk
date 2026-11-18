#Requires AutoHotkey v2.0
#SingleInstance Force

; ================= 权限检查与提权 =================
if !A_IsAdmin {
    try Run "*RunAs " A_ScriptFullPath
    catch {
        MsgBox("脚本需要管理员权限才能控制Clash及修改系统设置，请重试。", "权限不足")
    }
    ExitApp
}

; ================= 全局变量声明 =================
global MyGui, BtnNode16, BtnNode22, BtnProxy, BtnTun, BtnCmder
global BtnGoldPrice, BtnGoldUnit, BtnGoldRefresh
global GoldRequest, GoldRefreshing := false, GoldRequestStarted := 0
global GoldLastError := ""
global TunStatus := 0
global CurrentNode := ""
global BarHidden := false

; 尝试允许拖拽消息穿透
DllCall("ChangeWindowMessageFilter", "UInt", 0x233, "UInt", 1)
DllCall("ChangeWindowMessageFilter", "UInt", 0x049, "UInt", 1)

; ================= 配置 =================
HotKeyProxy := "^!+p"
HotKeyTun   := "^!+o"

ButtonWidth  := 100
ButtonHeight := 25
TotalHeight  := ButtonHeight * 2
CmderWidth   := TotalHeight

; 黄金区域配置
GoldWidth   := 82
RefreshWidth := 30
ColorGoldBg := "8C7848"
ColorRefreshBg := "555555"

; 颜色配置
ColorCmderBg   := "8bb91c"
ColorCmderText := "494b44"
ColorDark      := "333333"

; 总宽度
TotalWidth := CmderWidth + ButtonWidth * 2 + GoldWidth + RefreshWidth

; 窗口位置
PosX := 0
PosY := A_ScreenHeight - 48

; ================= GUI 创建 =================
MyGui := Gui("+AlwaysOnTop -Caption +ToolWindow +LastFound -DPIScale +E0x08000000")
MyGui.BackColor := ColorDark
MyGui.SetFont("s8 bold cWhite", "Segoe UI")

MyGui.OnEvent("DropFiles", OnFilesDropped)

; ================= Cmder 区域 =================
BtnCmder := MyGui.Add(
    "Text",
    Format("x0 y0 w{} h{} Center 0x200 Background{} c{}", CmderWidth, TotalHeight, ColorCmderBg, ColorCmderText),
    "λ"
)
BtnCmder.SetFont("s26 bold", "Consolas")
BtnCmder.OnEvent("Click", (*) => RunCmder())

; ================= Node 区域 =================
MyGui.SetFont("s8 bold cWhite", "Segoe UI")

NodeLabel := MyGui.Add(
    "Text",
    Format("x{} y0 w{} h{} Center 0x200", CmderWidth, ButtonWidth, ButtonHeight),
    " Node Version："
)

BtnNode16 := MyGui.Add(
    "Text",
    Format("x{} y{} w{} h{} Center 0x200", CmderWidth, ButtonHeight, ButtonWidth//2, ButtonHeight),
    "16"
)
BtnNode16.OnEvent("Click", (*) => SwitchNode(16))

BtnNode22 := MyGui.Add(
    "Text",
    Format("x{} y{} w{} h{} Center 0x200", CmderWidth + (ButtonWidth//2), ButtonHeight, ButtonWidth//2, ButtonHeight),
    "22"
)
BtnNode22.OnEvent("Click", (*) => SwitchNode(22))

; ================= Proxy / TUN 区域 =================
BtnProxy := MyGui.Add(
    "Text",
    Format("x{} y0 w{} h{} Center 0x200", CmderWidth + ButtonWidth, ButtonWidth, ButtonHeight),
    "Checking..."
)
BtnProxy.OnEvent("Click", OnProxyClick)

BtnTun := MyGui.Add(
    "Text",
    Format("x{} y{} w{} h{} Center 0x200", CmderWidth + ButtonWidth, ButtonHeight, ButtonWidth, ButtonHeight),
    "TUN OFF"
)
BtnTun.OnEvent("Click", OnTunClick)

; ================= 积存金价格区域 =================
GoldX := CmderWidth + ButtonWidth * 2

BtnGoldPrice := MyGui.Add(
    "Text",
    Format("x{} y0 w{} h30 Center 0x200 Background{} cWhite", GoldX, GoldWidth, ColorGoldBg),
    "--"
)
BtnGoldPrice.SetFont("s11 bold", "Segoe UI")

BtnGoldUnit := MyGui.Add(
    "Text",
    Format("x{} y30 w{} h20 Center 0x200 Background{} cWhite", GoldX, GoldWidth, ColorGoldBg),
    "RMB / g"
)
BtnGoldUnit.SetFont("s7", "Segoe UI")

; ================= 刷新按钮 =================
BtnGoldRefresh := MyGui.Add(
    "Text",
    Format("x{} y0 w{} h{} Center 0x200 Background{} cWhite",
        GoldX + GoldWidth, RefreshWidth, TotalHeight, ColorRefreshBg),
    "↻"
)
BtnGoldRefresh.SetFont("s18 bold", "Segoe UI Symbol")
BtnGoldRefresh.OnEvent("Click", OnGoldRefreshClick)

; ================= 显示窗口 =================
MyGui.Show(Format("w{} h{} x{} y{} NoActivate", TotalWidth, TotalHeight, PosX, PosY))

SetTimer CheckState, 500
CheckState()

; 积存金价格：每10秒刷新
SetTimer RefreshGoldPrice, 10000

; 启动时立即获取一次
RefreshGoldPrice()

OnMessage(0x0201, WM_LBUTTONDOWN)
return


; ================= 拖动窗口逻辑 =================
WM_LBUTTONDOWN(*) {
    global MyGui

    if GetKeyState("Ctrl", "P") {
        PostMessage(0xA1, 2, , , "ahk_id " MyGui.Hwnd)
        return 0
    }
}


; ================= Cmder 核心逻辑 =================
RunCmder(path := "") {
    Flash(BtnCmder)

    if (path == "") {
        path := "C:\Users\admin"
    }

    try {
        Run(Format('cmder /START "{}"', path))
    } catch as e {
        MsgBox("无法启动 Cmder，请确认：`n1. 'cmder' 已添加到环境变量 Path 中。`n2. 路径是否存在。`n`n错误: " e.Message, "启动失败")
    }
}

OnFilesDropped(GuiObj, GuiCtrlObj, FileArray, X, Y) {
    global CmderWidth

    if (X > CmderWidth) {
        return
    }

    if (FileArray.Length > 0) {
        targetPath := FileArray[1]

        attr := FileGetAttrib(targetPath)
        if (InStr(attr, "D")) {
            RunCmder(targetPath)
        } else {
            SplitPath targetPath, , &parentDir
            RunCmder(parentDir)
        }
    }
}


; ================= Proxy / TUN =================
OnProxyClick(*) {
    global HotKeyProxy, BtnProxy

    Send(HotKeyProxy)
    Flash(BtnProxy)
}

OnTunClick(*) {
    global TunStatus, HotKeyTun, BtnTun

    Send(HotKeyTun)
    TunStatus := !TunStatus
    Flash(BtnTun)
    UpdateTunUI()
}


; ================= 黄金价格获取（浙商积存金） =================

OnGoldRefreshClick(*) {
    global BtnGoldRefresh

    Flash(BtnGoldRefresh)
    RefreshGoldPrice()
}

RefreshGoldPrice() {
    global GoldRefreshing, GoldRequest, GoldRequestStarted

    if GoldRefreshing {
        return
    }

    GoldRefreshing := true

    try {
        GoldRequest := ComObject("WinHttp.WinHttpRequest.5.1")
        GoldRequest.SetTimeouts(5000, 5000, 5000, 5000)

        ; 京东金融浙商积存金接口，GET 方式，productSku 指定浙商产品
        url := "https://api.jdjygold.com/gw2/generic/jrm/h5/m/stdLatestPrice?productSku=1961543816"

        GoldRequest.Open("GET", url, true)

        ; 加移动端 UA，避免被拦截
        GoldRequest.SetRequestHeader("User-Agent",
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) "
            . "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1")
        GoldRequest.SetRequestHeader("Accept", "application/json, text/javascript, */*; q=0.01")

        GoldRequestStarted := A_TickCount
        GoldRequest.Send()
        SetTimer PollGoldRequest, 100

    } catch as e {
        FinishGoldRequest("请求启动失败：" e.Message)
    }
}

PollGoldRequest() {
    global GoldRequest, GoldRefreshing, GoldRequestStarted

    if !GoldRefreshing {
        SetTimer PollGoldRequest, 0
        return
    }

    try {
        if GoldRequest.WaitForResponse(0) {
            SetTimer PollGoldRequest, 0
            GoldHttp_OnResponseFinished()
        } else if (A_TickCount - GoldRequestStarted >= 20000) {
            FinishGoldRequest("网络请求超时（20 秒）")
        }
    } catch as e {
        FinishGoldRequest("网络请求失败：" e.Message)
    }
}

GoldHttp_OnResponseFinished(*) {
    global GoldRequest

    try {
        if !IsObject(GoldRequest) {
            return
        }

        status := GoldRequest.Status

        if (status != 200) {
            FinishGoldRequest("HTTP 请求失败：" status)
            return
        }

        response := GoldRequest.ResponseText

        ; 京东金融返回结构：resultData.datas.price
        ; 例如：{"resultData":{"datas":{"price":"1148.57",...}}}
        if RegExMatch(response, 's)"price"\s*:\s*"([0-9]+(?:\.[0-9]+)?)"', &match) {
            price := match[1]
        } else if RegExMatch(response, 's)"price"\s*:\s*([0-9]+(?:\.[0-9]+)?)', &match) {
            ; 兼容 price 为数字类型（非字符串）的情况
            price := match[1]
        } else {
            ; 尝试读取接口错误信息
            if RegExMatch(response, '"resultMsg"\s*:\s*"([^"]*)"', &errMatch) {
                FinishGoldRequest("京东金融接口：" errMatch[1])
            } else {
                FinishGoldRequest("未找到浙商积存金价格")
            }
            return
        }

        if (Number(price) <= 0) {
            FinishGoldRequest("价格数据无效")
            return
        }

        FinishGoldRequest("", price)

    } catch as e {
        FinishGoldRequest("解析行情失败：" e.Message)
    }
}

FinishGoldRequest(errorMessage := "", price := "") {
    global GoldRequest, GoldRefreshing, BtnGoldPrice, BtnGoldUnit, GoldLastError

    SetTimer PollGoldRequest, 0

    if (price != "") {
        BtnGoldPrice.Value := Format("{:.2f}", Number(price))
        BtnGoldPrice.Redraw()
        BtnGoldUnit.Value := "RMB / g"
        GoldLastError := ""
    }

    if (errorMessage != "") {
        BtnGoldUnit.Value := "获取失败"
        OutputDebug("[浙商积存金] " errorMessage)
        if (errorMessage != GoldLastError) {
            try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " " errorMessage "`n",
                A_ScriptDir "\gold-price.log", "UTF-8")
        }
        GoldLastError := errorMessage
    }
    BtnGoldUnit.Redraw()

    if IsObject(GoldRequest) {
        try GoldRequest.Abort()
    }

    GoldRequest := ""
    GoldRefreshing := false
}


; ================= 点击反馈动画 =================
Flash(ctrl) {
    ctrl.Opt("BackgroundWhite cBlack")
    ctrl.Redraw()
    SetTimer(() => (UpdateCtrlColor(ctrl)), -150)
}

UpdateCtrlColor(ctrl) {
    global ColorCmderBg, ColorCmderText
    global BtnCmder, BtnProxy, BtnTun, BtnNode16, BtnNode22

    if (ctrl == BtnCmder) {
        ctrl.Opt("Background" ColorCmderBg " c" ColorCmderText)
    } else if (ctrl == BtnGoldRefresh) {
        ctrl.Opt("Background555555 cWhite")
    } else {
        ctrl.Opt("BackgroundTrans cWhite")
    }

    if (ctrl == BtnProxy || ctrl == BtnTun || ctrl == BtnNode16 || ctrl == BtnNode22) {
        CheckState()
    } else {
        ctrl.Redraw()
    }
}


; ================= 状态检查 =================
CheckState() {
    global BtnProxy, ColorDark

    UpdateBarVisibility()

    try {
        enabled := RegRead(
            "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings",
            "ProxyEnable"
        )

        if enabled {
            BtnProxy.Opt("Background497dc6")
            BtnProxy.Value := "Proxy ON"
        } else {
            BtnProxy.Opt("Background" ColorDark)
            BtnProxy.Value := "Proxy OFF"
        }
    }

    UpdateTunUI()
    UpdateNodeUI()
}

; ================= 窗口层级与全屏隐藏 =================
UpdateBarVisibility() {
    global MyGui, BarHidden

    if IsFullscreenForeground() {
        if !BarHidden {
            BarHidden := true
            try WinHide("ahk_id " MyGui.Hwnd)
        }
        return
    }

    if BarHidden {
        BarHidden := false
        try WinShow("ahk_id " MyGui.Hwnd)
    }

    try WinSetAlwaysOnTop(1, "ahk_id " MyGui.Hwnd)
}

IsFullscreenForeground() {
    state := 0
    hr := -1
    try hr := DllCall("shell32\SHQueryUserNotificationState", "int*", &state, "int")

    if (hr = 0) {
        if (state = 3)
            return true
        if (state = 2 || state = 4)
            return IsForegroundWindowFullscreen()
        return false
    }

    return IsForegroundWindowFullscreen()
}

IsForegroundWindowFullscreen() {
    global MyGui

    hwnd := DllCall("GetForegroundWindow", "ptr")
    if !hwnd || (hwnd = MyGui.Hwnd)
        return false

    if !DllCall("IsWindowVisible", "ptr", hwnd)
        return false

    pageMon := DllCall("MonitorFromWindow", "ptr", hwnd, "uint", 2, "ptr")
    barMon := DllCall("MonitorFromWindow", "ptr", MyGui.Hwnd, "uint", 2, "ptr")
    if (pageMon != barMon)
        return false

    try cls := WinGetClass("ahk_id " hwnd)
    catch
        return false
    if (cls = "Progman" || cls = "WorkerW" || cls = "Shell_TrayWnd")
        return false

    try WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
    catch
        return false

    return (x <= 0 && y <= 0 && w >= A_ScreenWidth && h >= A_ScreenHeight)
}


UpdateTunUI() {
    global TunStatus, ColorDark, BtnTun

    if TunStatus {
        BtnTun.Opt("Background2d8634")
        BtnTun.Value := "TUN ON"
    } else {
        BtnTun.Opt("Background" ColorDark)
        BtnTun.Value := "TUN OFF"
    }
}

; ================= Node 版本控制 =================
SwitchNode(version) {
    global CurrentNode

    CurrentNode := version
    UpdateNodeUI()

    try {
        RunWait(A_ComSpec ' /c nvm use ' version, , "Hide")
    } catch {
        MsgBox("切换 Node 版本失败，请检查 nvm 是否安装。", "错误")
    }
}

UpdateNodeUI() {
    global CurrentNode, BtnNode16, BtnNode22

    SetNodeBtn(BtnNode16, CurrentNode == 16)
    SetNodeBtn(BtnNode22, CurrentNode == 22)
}

SetNodeBtn(btn, active) {
    if active {
        btn.Opt("Background7a66fa")
    } else {
        btn.Opt("BackgroundTrans")
    }
    btn.Redraw()
}