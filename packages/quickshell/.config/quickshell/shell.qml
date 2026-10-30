
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower
import QtQuick

Scope {
    id: root

    // Jam: binding reaktif — Text di bawah ikut berubah tiap `now` berubah.
    // Mirip state di JS/TS: ubah sumbernya, UI-nya ikut.
    property var now: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            color: "transparent"

            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: 32

            // Latar ala Waybar papa: rgba(30, 30, 46, 0.75), sudut membulat.
            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                radius: 12
                color: "#bf1e1e2e"
            }

            // Kiri: workspace 1-9. Klik = pindah workspace via dispatcher Hyprland.
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Repeater {
                    model: 9

                    Rectangle {
                        required property int index
                        width: 28
                        height: 24
                        radius: 8
                        color: (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === index + 1) ? "#89b4fa" : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: (index + 1).toString()
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            color: (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === index + 1) ? "#1e1e2e" : "#cdd6f4"
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: Hyprland.dispatch("workspace " + (index + 1))
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: Qt.formatDateTime(root.now, "dddd, dd MMM  HH:mm")
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: "#cdd6f4"
            }

            // Kanan: indikator baterai via UPower.displayDevice.
            // percentage berupa desimal 0-1, jadi dikali 100. state 1 = charging.
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: UPower.displayDevice ? Math.round(UPower.displayDevice.percentage * 100) + "%" + (UPower.displayDevice.state === 1 ? " ⚡" : "") : ""
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: "#cdd6f4"
            }
        }
    }
}