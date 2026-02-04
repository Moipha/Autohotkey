#Requires AutoHotkey v2.0
#SingleInstance Force

if not A_IsAdmin {
    try Run "*RunAs " A_ScriptFullPath
    catch {
        MsgBox("脚本需要管理员权限才能控制Clash及修改系统设置，请重试。", "权限不足")
    }
    ExitApp
}

; ---------------- 全局变量声明 ----------------
; 在 v2 中，为了在函数内访问这些 GUI 对象，建议声明为全局变量
global MyGui, BtnNode16, BtnNode22, BtnProxy, BtnTun
global TunStatus := 0
global CurrentNode := ""
; ---------------------------------------------

; ---------------- 配置 ----------------
HotKeyProxy := "^!+p"
HotKeyTun   := "^!+o"

ButtonWidth  := 100
ButtonHeight := 25
TotalHeight  := ButtonHeight * 2
TotalWidth   := ButtonWidth * 2

PosX := A_ScreenWidth - TotalWidth - 280
PosY := A_ScreenHeight - 48
; -------------------------------------

MyGui := Gui("+AlwaysOnTop -Caption +ToolWindow +LastFound -DPIScale +E0x08000000")
MyGui.BackColor := "333333"
MyGui.SetFont("s8 bold cWhite", "Segoe UI")

; ================= Node 区域 =================

NodeLabel := MyGui.Add(
    "Text",
    Format("x0 y0 w{} h{} Center 0x200", ButtonWidth, ButtonHeight),
    " Node Version："
)

BtnNode16 := MyGui.Add(
    "Text",
    Format("x0 y{} w{} h{} Center 0x200",
        ButtonHeight,
        ButtonWidth//2,
        ButtonHeight
    ),
    "16"
)
BtnNode16.OnEvent("Click", (*) => SwitchNode(16))

BtnNode22 := MyGui.Add(
    "Text",
    Format("x{} y{} w{} h{} Center 0x200",
        ButtonWidth//2,
        ButtonHeight,
        ButtonWidth//2,
        ButtonHeight
    ),
    "22"
)
BtnNode22.OnEvent("Click", (*) => SwitchNode(22))

; ================= 右侧按钮 =================

BtnProxy := MyGui.Add(
    "Text",
    Format("x{} y0 w{} h{} Center 0x200",
        ButtonWidth,
        ButtonWidth,
        ButtonHeight
    ),
    "Checking..."
)
BtnProxy.OnEvent("Click", OnProxyClick)

BtnTun := MyGui.Add(
    "Text",
    Format("x{} y{} w{} h{} Center 0x200",
        ButtonWidth,
        ButtonHeight,
        ButtonWidth,
        ButtonHeight
    ),
    "TUN OFF"
)
BtnTun.OnEvent("Click", OnTunClick)

MyGui.Show(
    Format("w{} h{} x{} y{} NoActivate",
        TotalWidth,
        TotalHeight,
        PosX,
        PosY
    )
)

SetTimer CheckState, 1000
CheckState()

OnMessage(0x0201, WM_LBUTTONDOWN)
return

; ================= 拖动 =================

WM_LBUTTONDOWN(*) {
    if GetKeyState("Ctrl", "P") {
        PostMessage(0xA1, 2, , , "ahk_id " MyGui.Hwnd)
        return 0
    }
}

; ================= Proxy / TUN =================

OnProxyClick(*) {
    Send(HotKeyProxy)
    Flash(BtnProxy)
}

OnTunClick(*) {
    global TunStatus
    Send(HotKeyTun)
    TunStatus := !TunStatus
    Flash(BtnTun)
    UpdateTunUI()
}

Flash(ctrl) {
    ctrl.Opt("BackgroundCCCCCC")
    ctrl.Redraw()
    SetTimer(() => (ctrl.Opt("BackgroundTrans"), ctrl.Redraw()), -120)
}

CheckState() {
    try WinSetAlwaysOnTop(1, "ahk_id " MyGui.Hwnd)

    try {
        enabled := RegRead(
            "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings",
            "ProxyEnable"
        )
        if enabled {
            BtnProxy.Opt("Background497dc6")
            BtnProxy.Value := "Proxy ON"
        } else {
            BtnProxy.Opt("Background333333")
            BtnProxy.Value := "Proxy OFF"
        }
    }

    UpdateTunUI()
    UpdateNodeUI()
}

UpdateTunUI() {
    global TunStatus
    if TunStatus {
        BtnTun.Opt("Background2d8634")
        BtnTun.Value := "TUN ON"
    } else {
        BtnTun.Opt("Background333333")
        BtnTun.Value := "TUN OFF"
    }
}

; ================= Node（纯 UI 状态）=================

SwitchNode(version) {
    global CurrentNode
    CurrentNode := version
    UpdateNodeUI()
    
    try {
        ; nvm-windows 修改的是系统环境变量，RunWait 结束后通常全局生效
        RunWait(A_ComSpec ' /c nvm use ' version, , "Hide")
    } catch {
        MsgBox("切换 Node 版本失败，请检查 nvm 是否安装。", "错误")
    }
}

UpdateNodeUI() {
    global CurrentNode
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