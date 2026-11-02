#!/usr/bin/env bash
# Power menu rofi - Catppuccin Mocha (tema dari config.rasi di folder yang sama).
# Dipanggil dari hyprland.lua dengan Super+X.
# Lock memakai loginctl lock-session, supaya hypridle menjalankan hyprlock.

choice=$(printf "Lock\nSuspend\nHibernate\nReboot\nPower-off" | rofi -dmenu -i -p "Power")

case "$choice" in
    Lock)
        loginctl lock-session
        ;;
    Suspend)
        systemctl suspend
        ;;
    Hibernate)
        systemctl hibernate
        ;;
    Reboot)
        systemctl reboot
        ;;
    Power-off)
        systemctl poweroff
        ;;
    *)
        ;;
esac
