#Requires AutoHotkey v2.0
#SingleInstance Force

; ================= 权限检查与提权 =================
if not A_IsAdmin {
    try Run "*RunAs " A_ScriptFullPath
    catch {
        MsgBox("脚本需要管理员权限才能控制Clash及修改系统设置，请重试。", "权限不足")
    }
    ExitApp
}

; ================= 全局变量声明 =================
global MyGui, BtnNode16, BtnNode22, BtnProxy, BtnTun, BtnCmder
global TunStatus := 0
global CurrentNode := ""

; 尝试允许拖拽消息穿透 (解决管理员权限下的拖拽限制，部分系统可能仍无效)
DllCall("ChangeWindowMessageFilter", "UInt", 0x233, "UInt", 1) ; WM_DROPFILES
DllCall("ChangeWindowMessageFilter", "UInt", 0x049, "UInt", 1) ; WM_COPYGLOBALDATA

; ================= 配置 =================
HotKeyProxy := "^!+p"
HotKeyTun   := "^!+o"

ButtonWidth  := 100
ButtonHeight := 25
TotalHeight  := ButtonHeight * 2
CmderWidth   := TotalHeight ; 保持正方形 50x50

; 颜色配置
ColorCmderBg   := "8bb91c"  ; Cmder 绿色
ColorCmderText := "494b44"  ; Cmder 深灰
ColorDark      := "333333"

; 总宽度
TotalWidth   := CmderWidth + (ButtonWidth * 2)

; 窗口位置（右下角）
PosX := 0
PosY := A_ScreenHeight - 48
; -------------------------------------

MyGui := Gui("+AlwaysOnTop -Caption +ToolWindow +LastFound -DPIScale +E0x08000000")
MyGui.BackColor := ColorDark
MyGui.SetFont("s8 bold cWhite", "Segoe UI")

; 开启拖拽文件支持
MyGui.OnEvent("DropFiles", OnFilesDropped)

; ================= Cmder 区域 (左侧方块) =================
; λ 图标按钮
BtnCmder := MyGui.Add(
    "Text",
    Format("x0 y0 w{} h{} Center 0x200 Background{} c{}", CmderWidth, TotalHeight, ColorCmderBg, ColorCmderText),
    "λ"
)
; 单独设置 Cmder 按钮的字体，使其看起来像图标
BtnCmder.SetFont("s26 bold", "Consolas")
BtnCmder.OnEvent("Click", (*) => RunCmder())

; ================= Node 区域 =================

MyGui.SetFont("s8 bold cWhite", "Segoe UI") ; 恢复默认字体

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

; ================= 右侧按钮 (Proxy/TUN) =================

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

; ================= 显示窗口 =================
MyGui.Show(Format("w{} h{} x{} y{} NoActivate", TotalWidth, TotalHeight, PosX, PosY))

; 定时检查状态
SetTimer CheckState, 1000
CheckState()

; 允许按住左键拖动窗口
OnMessage(0x0201, WM_LBUTTONDOWN)
return

; ================= 拖动窗口逻辑 =================
WM_LBUTTONDOWN(*) {
    if GetKeyState("Ctrl", "P") {
        PostMessage(0xA1, 2, , , "ahk_id " MyGui.Hwnd)
        return 0
    }
}

; ================= Cmder 核心逻辑 =================

RunCmder(path := "") {
    Flash(BtnCmder)

    ; 如果没有指定路径（直接点击），则强制设置为 C:\Users\admin
    if (path == "") {
        path := "C:\Users\admin"
        ; 提示：如果你想自动适配当前用户，可以使用 path := A_UserProfile
    }

    try {
        ; 使用 /START 参数启动到指定路径
        ; 注意：引号是必须的，防止路径含空格报错
        Run(Format('cmder /START "{}"', path))
    } catch as e {
        MsgBox("无法启动 Cmder，请确认：`n1. 'cmder' 已添加到环境变量 Path 中。`n2. 路径是否存在。`n`n错误: " e.Message, "启动失败")
    }
}

; 处理拖拽文件事件
OnFilesDropped(GuiObj, GuiCtrlObj, FileArray, X, Y) {
    global CmderWidth

    ; 限制：只有拖拽到左侧绿色区域 (X < 50) 才触发
    if (X > CmderWidth) {
        return
    }

    if (FileArray.Length > 0) {
        targetPath := FileArray[1]

        ; 智能判断：如果是文件，取其目录；如果是文件夹，直接使用
        attr := FileGetAttrib(targetPath)
        if (InStr(attr, "D")) {
            ; 是文件夹
            RunCmder(targetPath)
        } else {
            ; 是文件，取父目录
            SplitPath targetPath, , &parentDir
            RunCmder(parentDir)
        }
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

; 点击反馈动画
Flash(ctrl) {
    ctrl.Opt("BackgroundWhite cBlack") ; 点击瞬间变白
    ctrl.Redraw()
    SetTimer(() => (UpdateCtrlColor(ctrl)), -150)
}

; 恢复控件颜色
UpdateCtrlColor(ctrl) {
    global ColorCmderBg, ColorCmderText, ColorDark

    if (ctrl == BtnCmder) {
        ; 恢复 Cmder 样式
        ctrl.Opt("Background" ColorCmderBg " c" ColorCmderText)
    } else {
        ; 恢复其他按钮样式
        ctrl.Opt("BackgroundTrans cWhite")
    }

    ; 针对状态按钮，需要重新读取状态来决定颜色
    if (ctrl == BtnProxy || ctrl == BtnTun || ctrl == BtnNode16 || ctrl == BtnNode22) {
        CheckState()
    } else {
        ctrl.Redraw()
    }
}

; ================= 状态检查 =================

CheckState() {
    try WinSetAlwaysOnTop(1, "ahk_id " MyGui.Hwnd)

    ; 检查系统代理状态
    try {
        enabled := RegRead(
            "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings",
            "ProxyEnable"
        )
        if enabled {
            BtnProxy.Opt("Background497dc6") ; 蓝色
            BtnProxy.Value := "Proxy ON"
        } else {
            BtnProxy.Opt("Background" ColorDark)
            BtnProxy.Value := "Proxy OFF"
        }
    }

    UpdateTunUI()
    UpdateNodeUI()
}

UpdateTunUI() {
    global TunStatus, ColorDark
    if TunStatus {
        BtnTun.Opt("Background2d8634") ; 绿色
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
    global CurrentNode
    SetNodeBtn(BtnNode16, CurrentNode == 16)
    SetNodeBtn(BtnNode22, CurrentNode == 22)
}

SetNodeBtn(btn, active) {
    if active {
        btn.Opt("Background7a66fa") ; 紫色
    } else {
        btn.Opt("BackgroundTrans")
    }
    btn.Redraw()
}