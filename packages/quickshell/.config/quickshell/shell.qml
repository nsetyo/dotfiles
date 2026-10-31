// shell.qml — DRAF indikator CPU lingkaran ala end_4, untuk bar Quickshell papa
// Basis: draf shell.qml yang sudah jalan di laptop papa (workspace 1-9 + jam +
// baterai UPower, PanelWindow color: "transparent").
// DRAF BELUM DIUJI di laptop papa. Yang sudah diverifikasi dari sumber:
// - Pola Process + StdioCollector + Timer dari panduan resmi Quickshell
//   (quickshell.org/docs/v0.2.1/guide/introduction/): Process menjalankan
//   satu perintah, StdioCollector.onStreamFinished menerima this.text,
//   Timer memicu ulang dengan `proc.running = true`.
// - Rumus CPU dari /proc/stat: cpuUsage = 1 - selisih idle / selisih total,
//   idle = idle + iowait; polling tiap 3 detik, sama seperti end_4.
// - end_4: lingkaran progres 20 piksel + ikon di tengah + persen di samping.
//   Versi ini tanpa ikon Material Symbols (belum terpasang di laptop papa):
//   lingkarannya saja + persen di samping.
// Catatan: persen baru muncul setelah polling kedua (~6 detik), karena
// polling pertama hanya menyimpan titik awal untuk menghitung selisih.
// Cara coba: simpan sebagai ~/.config/quickshell/shell.qml (backup dulu
// yang lama), bar ikut reload sendiri. Kalau lingkaran tidak muncul,
// kirim pesan error Quickshell-nya ke Jessi.

import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Io
import QtQuick

Scope {
    id: root

    // Jam: binding reaktif — Text di bawah ikut berubah tiap `now` berubah.
    property var now: new Date()

    // CPU: 0-1, dihitung dari selisih /proc/stat antar polling.
    property real cpuUsage: 0
    property real lastCpuTotal: -1
    property real lastCpuIdle: -1

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    // Baca baris "cpu ..." dari /proc/stat tiap 3 detik, lalu hitung
    // pemakaian dari selisih terhadap polling sebelumnya.
    Process {
        id: cpuProc
        command: ["sh", "-c", "head -n 1 /proc/stat"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split(/\s+/);
                // parts[0] = "cpu", sisanya: user nice system idle iowait
                // irq softirq steal guest guest_nice.
                if (parts.length < 5 || parts[0] !== "cpu")
                    return;
                var nums = [];
                for (var i = 1; i < parts.length; i++)
                    nums.push(parseInt(parts[i], 10));
                var total = 0;
                for (var j = 0; j < nums.length; j++)
                    total += nums[j];
                var idle = nums[3] + nums[4]; // idle + iowait
                if (root.lastCpuTotal >= 0 && total > root.lastCpuTotal) {
                    var totalDiff = total - root.lastCpuTotal;
                    var idleDiff = idle - root.lastCpuIdle;
                    root.cpuUsage = Math.max(0, Math.min(1, 1 - idleDiff / totalDiff));
                }
                root.lastCpuTotal = total;
                root.lastCpuIdle = idle;
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: cpuProc.running = true
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            // Penting: tanpa ini jendela bar jadi opaque (hitam pekat).
            // Warna bar sendiri tetap dari Rectangle di bawah.
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

            // Tengah: jam, format sama dengan Waybar papa: "%A, %d %b  %H:%M".
            Text {
                anchors.centerIn: parent
                text: Qt.formatDateTime(root.now, "dddd, dd MMM  HH:mm")
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: "#cdd6f4"
            }

            // Kanan: lingkaran CPU + persen, lalu indikator baterai.
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // Lingkaran progres 20 piksel ala end_4 (tanpa ikon tengah).
                // Warna biru #89b4fa seperti workspace aktif; merah #f38ba8
                // kalau pemakaian melewati 80%, seperti ambang end_4.
                Canvas {
                    id: cpuRing
                    width: 20
                    height: 20
                    anchors.verticalCenter: parent.verticalCenter
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.lineWidth = 2.5;
                        ctx.lineCap = "round";
                        // Latar lingkaran.
                        ctx.beginPath();
                        ctx.strokeStyle = "#313244";
                        ctx.arc(width / 2, height / 2, 8, 0, Math.PI * 2);
                        ctx.stroke();
                        // Busur pemakaian, mulai dari atas.
                        ctx.beginPath();
                        ctx.strokeStyle = root.cpuUsage > 0.8 ? "#f38ba8" : "#89b4fa";
                        ctx.arc(width / 2, height / 2, 8, -Math.PI / 2, -Math.PI / 2 + root.cpuUsage * Math.PI * 2);
                        ctx.stroke();
                    }
                    Component.onCompleted: requestPaint()
                }

                // Gambar ulang lingkaran tiap persen berubah.
                Connections {
                    target: root
                    function onCpuUsageChanged() { cpuRing.requestPaint(); }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(root.cpuUsage * 100) + "%"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: "#cdd6f4"
                }

                // Indikator baterai via UPower.displayDevice (agregat baterai).
                // percentage di Quickshell berupa desimal 0-1, jadi dikali 100.
                // state 1 = charging (enum UPower: 1 charging, 2 discharging).
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: UPower.displayDevice ? Math.round(UPower.displayDevice.percentage * 100) + "%" + (UPower.displayDevice.state === 1 ? " ⚡" : "") : ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: "#cdd6f4"
                }
            }
        }
    }
}
