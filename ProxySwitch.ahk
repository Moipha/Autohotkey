
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
global BarHidden := false            ; 全屏时整条栏是否已隐藏

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
; 工具栏正好压在任务栏那条 48px 上：必须置顶，否则会被任务栏压住、点不到；
; 全屏页面（F11 / 全屏视频 / 全屏游戏）出现时由 UpdateBarVisibility 整条隐藏。
MyGui := Gui("+AlwaysOnTop -Caption +ToolWindow +LastFound -DPIScale +E0x08000000")
MyGui.BackColor := ColorDark
MyGui.SetFont("s8 bold cWhite", "Segoe UI")

; 开启拖拽文件支持
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

; 第一行：价格
BtnGoldPrice := MyGui.Add(
    "Text",
    Format("x{} y0 w{} h30 Center 0x200 Background{} cWhite", GoldX, GoldWidth, ColorGoldBg),
    "--"
)
BtnGoldPrice.SetFont("s11 bold", "Segoe UI")

; 第二行：单位
BtnGoldUnit := MyGui.Add(
    "Text",
    Format("x{} y30 w{} h20 Center 0x200 Background{} cWhite", GoldX, GoldWidth, ColorGoldBg),
    "RMB / g"
)
BtnGoldUnit.SetFont("s7", "Segoe UI")

; ================= 黄金价格刷新按钮 =================
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

; 定时检查状态（顺便决定整条栏是否要让位给全屏页面）
SetTimer CheckState, 500
CheckState()

; 积存金价格：每10秒刷新
SetTimer RefreshGoldPrice, 10000

; 启动时立即获取一次
RefreshGoldPrice()

; 允许按住左键拖动窗口
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

; 处理拖拽文件事件
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


; ================= 黄金价格获取 =================

; 手动刷新按钮
OnGoldRefreshClick(*) {
    global BtnGoldRefresh

    Flash(BtnGoldRefresh)
    RefreshGoldPrice()
}

; 发起异步请求
RefreshGoldPrice() {
    global GoldRefreshing, GoldRequest, GoldRequestStarted

    ; 防止重复请求
    if GoldRefreshing {
        return
    }

    GoldRefreshing := true

    try {
        GoldRequest := ComObject("WinHttp.WinHttpRequest.5.1")

        ; 设置超时时间：DNS、连接、发送、接收
        GoldRequest.SetTimeouts(5000, 5000, 5000, 5000)

        GoldRequest.Open(
            "POST",
            "https://mybank.icbc.com.cn/servlet/AsynGetDataServlet",
            true
        )

        GoldRequest.SetRequestHeader(
            "Content-Type",
            "application/x-www-form-urlencoded; charset=UTF-8"
        )

        GoldRequest.SetRequestHeader(
            "Accept",
            "application/json, text/javascript, */*; q=0.01"
        )

        ; WinHttpRequest 不支持 ComObjConnect，使用零等待轮询检查异步结果。
        GoldRequestStarted := A_TickCount
        GoldRequest.Send("tranCode=A00622")
        SetTimer PollGoldRequest, 100

    } catch as e {
        FinishGoldRequest("请求启动失败：" e.Message)
    }
}

; WaitForResponse(0) 立即返回，避免等待网络时阻塞 GUI。
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

; HTTP 请求完成后解析行情
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

        ; 优先匹配 ProductName = 积存金 的记录
        pattern := 's)\{(?=[^{}]*"ProductName"\s*:\s*"积存金")(?=[^{}]*"ActivePrice"\s*:\s*"?([0-9]+(?:\.[0-9]+)?))[^{}]*\}'

        if !RegExMatch(response, pattern, &match) {
            ; 备用匹配：通过产品代码定位
            pattern := 's)\{(?=[^{}]*"proCode"\s*:\s*"?080020000521"?)(?=[^{}]*"ActivePrice"\s*:\s*"?([0-9]+(?:\.[0-9]+)?))[^{}]*\}'

            if !RegExMatch(response, pattern, &match) {
                ; 尝试读取工行接口错误信息
                if RegExMatch(response, '"TranErrorDisplayMsg"\s*:\s*"([^"]*)"', &errMatch) {
                    FinishGoldRequest("工行接口：" errMatch[1])
                } else {
                    FinishGoldRequest("未找到有效的主动积存价格")
                }
                return
            }
        }

        price := match[1]

        if (Number(price) <= 0) {
            FinishGoldRequest("价格数据无效")
            return
        }

        FinishGoldRequest("", price)

    } catch as e {
        FinishGoldRequest("解析行情失败：" e.Message)
    }
}

; 统一处理请求完成
FinishGoldRequest(errorMessage := "", price := "") {
    global GoldRequest, GoldRefreshing, BtnGoldPrice, BtnGoldUnit, GoldLastError

    SetTimer PollGoldRequest, 0

    ; 更新价格
    if (price != "") {
        BtnGoldPrice.Value := Format("{:.2f}", Number(price))
        BtnGoldPrice.Redraw()
        BtnGoldUnit.Value := "RMB / g"
        GoldLastError := ""
    }

    ; 失败时保留上一次成功价格，同时标记数据可能已过期。
    if (errorMessage != "") {
        BtnGoldUnit.Value := "获取失败"
        OutputDebug("[工行积存金] " errorMessage)
        ; 相同错误只记录一次，避免每 10 秒重复写日志。
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

; 恢复控件颜色
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

    ; 先决定层级 / 是否隐藏，再刷新状态
    UpdateBarVisibility()

    ; 检查系统代理状态
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
; 工具栏压在任务栏那条 48px 上，必须置顶才看得见、点得到；
; 但 F11 页面 / 全屏视频 / 全屏游戏出现时要把整条栏藏起来，不能压住全屏内容。

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

    ; 持续校正置顶：任务栏、播放器等也置顶，不校正就会被压住点不到
    try WinSetAlwaysOnTop(1, "ahk_id " MyGui.Hwnd)
}

; 前台是否处于全屏
IsFullscreenForeground() {
    ; Shell 的通知状态直接反映前台全屏：
    ; QUNS_BUSY(2) / QUNS_RUNNING_D3D_FULL_SCREEN(3) / QUNS_PRESENTATION_MODE(4)
    state := 0
    hr := -1
    try hr := DllCall("shell32\SHQueryUserNotificationState", "int*", &state, "int")

    if (hr = 0) {
        if (state = 3)                      ; 独占全屏（D3D）：系统层面必定是全屏
            return true
        if (state = 2 || state = 4)         ; 普通全屏 / 演示模式：再确认前台窗口确实铺满屏幕
            return IsForegroundWindowFullscreen()
        return false                        ; QUNS_ACCEPTS_NOTIFICATIONS 等按非全屏处理
    }

    ; 系统接口不可用时退回窗口几何判断
    return IsForegroundWindowFullscreen()
}

; 前台窗口是否铺满整块屏幕（最大化窗口只铺满工作区，不算）
IsForegroundWindowFullscreen() {
    global MyGui

    hwnd := DllCall("GetForegroundWindow", "ptr")
    if !hwnd || (hwnd = MyGui.Hwnd)
        return false

    if !DllCall("IsWindowVisible", "ptr", hwnd)
        return false

    ; 只处理与整体栏同一显示器上的全屏页面
    pageMon := DllCall("MonitorFromWindow", "ptr", hwnd, "uint", 2, "ptr")
    barMon := DllCall("MonitorFromWindow", "ptr", MyGui.Hwnd, "uint", 2, "ptr")
    if (pageMon != barMon)
        return false

    ; 桌面、任务栏本身不是全屏页面
    try cls := WinGetClass("ahk_id " hwnd)
    catch
        return false
    if (cls = "Progman" || cls = "WorkerW" || cls = "Shell_TrayWnd")
        return false

    try WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
    catch
        return false

    ; 盖住整个屏幕（含任务栏区域）才算全屏；只铺满工作区的大窗口不算
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
