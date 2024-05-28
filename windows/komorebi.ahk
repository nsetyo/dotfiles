#SingleInstance Force

; Load library
#Include komorebic.lib.ahk

; Focus windows
#h::Focus("left")
#j::Focus("down")
#k::Focus("up")
#l::Focus("right")
#Left::Focus("left")
#Right::Focus("right")
#Up::Focus("up")
#Down::Focus("down")
#+[::CycleFocus("previous")
#+]::CycleFocus("next")

; Move windows
#+h::Move("left")
#+j::Move("down")
#+k::Move("up")
#+l::Move("right")
#+Left::Move("left")
#+Right::Move("right")
#+Up::Move("up")
#+Down::Move("down")
#+Enter::Promote()

; Stack windows
^!Left::Stack("left")
^!Right::Stack("right")
^!Up::Stack("up")
^!Down::Stack("down")
#;::Unstack()
#[::CycleStack("previous")
#]::CycleStack("next")

; Resize
#=::ResizeAxis("horizontal", "increase")
#-::ResizeAxis("horizontal", "decrease")
#+=::ResizeAxis("vertical", "increase")
#+-::ResizeAxis("vertical", "decrease")

; Manipulate windows
#t::ToggleFloat()
#+f::ToggleMonocle()

; Window manager options
#+r::Retile()
#p::TogglePause()

; Layouts
#x::FlipLayout("horizontal")
#y::FlipLayout("vertical")

; Workspaces
#1::FocusWorkspace(0)
#2::FocusWorkspace(1)
#3::FocusWorkspace(2)
#4::FocusWorkspace(3)
#5::FocusWorkspace(4)

; Move windows across workspaces
#+1::MoveToWorkspace(0)
#+2::MoveToWorkspace(1)
#+3::MoveToWorkspace(2)
#+4::MoveToWorkspace(3)
#+5::MoveToWorkspace(4)


#+Q::WinClose "A"

#Enter::Run 'alacritty'
