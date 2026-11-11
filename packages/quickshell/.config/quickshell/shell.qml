// shell.qml — DRAF indikator CPU lingkaran ala end_4, untuk bar Quickshell papa
// Basis: draf shell.qml yang sudah jalan di laptop papa (workspace 1-9 + jam +
// baterai UPower, PanelWindow color: "transparent").
// Ikon tengah: "memory" dari Material Symbols Rounded
// (paket Arch resmi ttf-material-symbols-variable, terpasang 2 Nov 2026).
// Yang sudah diverifikasi dari sumber:
// - Pola Process + StdioCollector + Timer dari panduan resmi Quickshell
//   (quickshell.org/docs/v0.2.1/guide/introduction/): Process menjalankan
//   satu perintah, StdioCollector.onStreamFinished menerima this.text,
//   Timer memicu ulang dengan `proc.running = true`.
// - Rumus CPU dari /proc/stat: cpuUsage = 1 - selisih idle / selisih total,
//   idle = idle + iowait; polling tiap 3 detik, sama seperti end_4.
// - Rumus RAM dari /proc/meminfo: ramUsage = 1 - MemAvailable / MemTotal,
//   polling tiap 3 detik juga, lingkaran sama seperti CPU (20 piksel,
//   ikon "memory_alt" di tengah, persen di samping, counter-clockwise).
// - Brightness dari brightnessctl: persen = g * 100 / m, polling tiap
//   3 detik, ikon + persen seperti baterai (ikon berubah sesuai level).
// - Volume dari wpctl get-volume @DEFAULT_AUDIO_SINK@: "Volume: 0.50"
//   atau "... [MUTED]", polling tiap 3 detik, ikon + persen seperti
//   baterai (ikon berubah sesuai level / mute).
// - Brightness instan via IPC: keybind brightness di hyprland.lua
//   menjalankan `quickshell ipc call brightness refresh` setelah
//   brightnessctl, jadi indikator berubah langsung tanpa menunggu
//   polling 3 detik (polling tetap jalan sebagai fallback, mis. saat
//   hypridle meredupkan layar).
// - end_4: lingkaran progres 20 piksel + ikon di tengah + persen di samping.
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
    // RAM: 0-1, dihitung dari /proc/meminfo tiap polling.
    property real ramUsage: 0
    // Brightness: 0-1, dari brightnessctl (g / m).
    property real brightness: 0
    // Volume: 0-1, dari wpctl get-volume; muted kalau ada [MUTED].
    property real volume: 0
    property bool volumeMuted: false
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

    // Baca MemTotal dan MemAvailable dari /proc/meminfo tiap 3 detik.
    Process {
        id: ramProc
        command: ["sh", "-c", "grep -E '^(MemTotal|MemAvailable):' /proc/meminfo"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var total = -1;
                var avail = -1;
                var lines = this.text.trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].trim().split(/\s+/);
                    if (parts[0] === "MemTotal:") total = parseInt(parts[1], 10);
                    if (parts[0] === "MemAvailable:") avail = parseInt(parts[1], 10);
                }
                if (total > 0 && avail >= 0)
                    root.ramUsage = Math.max(0, Math.min(1, 1 - avail / total));
            }
        }
    }

    // Brightness: persen = brightnessctl g * 100 / brightnessctl m.
    Process {
        id: brightnessProc
        command: ["sh", "-c", "echo $(( $(brightnessctl g) * 100 / $(brightnessctl m) ))"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var pct = parseInt(this.text.trim(), 10);
                if (!isNaN(pct))
                    root.brightness = Math.max(0, Math.min(1, pct / 100));
            }
        }
    }

    // Volume: "Volume: 0.50" atau "Volume: 0.50 [MUTED]".
    Process {
        id: volumeProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split(/\s+/);
                if (parts.length < 2 || parts[0] !== "Volume:")
                    return;
                var v = parseFloat(parts[1]);
                if (!isNaN(v))
                    root.volume = Math.max(0, Math.min(1, v));
                root.volumeMuted = this.text.indexOf("MUTED") !== -1;
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            cpuProc.running = true;
            ramProc.running = true;
            brightnessProc.running = true;
            volumeProc.running = true;
        }
    }

    // IPC: keybind brightness di hyprland.lua memanggil
    // `quickshell ipc call brightness refresh` setelah brightnessctl,
    // supaya indikator berubah instan tanpa menunggu polling 3 detik.
    // IpcHandler ada di Quickshell.Io (sudah di-import di atas).
    IpcHandler {
        target: "brightness"

        function refresh(): void {
            brightnessProc.running = true;
        }
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
            // Rounding pill aktif selaras dengan sudut bar: latar bar radius 12
            // dengan margin 3; pill inset 2px dari latar (kiri & atas sama) sehingga
            // radius pill = 12 - 2 = 10, konsentris dengan sudut bar.
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Repeater {
                    model: 9

                    Rectangle {
                        required property int index
                        width: 28
                        height: 22
                        radius: 10
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

            // Kanan: lingkaran CPU + persen, lingkaran RAM + persen,
            // brightness + persen, volume + persen, lalu indikator baterai.
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // Indikator brightness: ikon berubah sesuai level, persen di samping.
                // brightness_high >= 70%, brightness_medium >= 40%, sisanya low.
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.brightness >= 0.7 ? "brightness_high" : root.brightness >= 0.4 ? "brightness_medium" : "brightness_low"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 16
                    color: "#cdd6f4"
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(root.brightness * 100) + "%"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: "#cdd6f4"
                }

                // Indikator volume: ikon berubah sesuai level / mute, persen di samping.
                // Muted menampilkan teks "Muted", bukan persen.
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.volumeMuted ? "volume_off" : root.volume >= 0.5 ? "volume_up" : root.volume > 0 ? "volume_down" : "volume_mute"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 16
                    color: "#cdd6f4"
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.volumeMuted ? "Muted" : Math.round(root.volume * 100) + "%"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: "#cdd6f4"
                }

                // Lingkaran progres 20 piksel ala end_4, dengan ikon
                // "memory" Material Symbols Rounded di tengahnya.
                // Warna biru #89b4fa seperti workspace aktif; merah #f38ba8
                // kalau pemakaian melewati 80%, seperti ambang end_4.
                Item {
                    width: 20
                    height: 20
                    anchors.verticalCenter: parent.verticalCenter

                    Canvas {
                        id: cpuRing
                        anchors.fill: parent
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
                            // Busur pemakaian, mulai dari atas, berlawanan jarum jam (counter-clockwise).
                            ctx.beginPath();
                            ctx.strokeStyle = root.cpuUsage > 0.8 ? "#f38ba8" : "#89b4fa";
                            ctx.arc(width / 2, height / 2, 8, -Math.PI / 2, -Math.PI / 2 - root.cpuUsage * Math.PI * 2, true);
                            ctx.stroke();
                        }
                        Component.onCompleted: requestPaint()
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "memory"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 12
                        color: "#cdd6f4"
                    }
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

                // Lingkaran RAM 20 piksel, sama seperti CPU (counter-clockwise),
                // ikon "memory_alt" di tengah. Warna hijau #a6e3a1; merah #f38ba8
                // kalau pemakaian melewati 80%.
                Item {
                    width: 20
                    height: 20
                    anchors.verticalCenter: parent.verticalCenter

                    Canvas {
                        id: ramRing
                        anchors.fill: parent
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.lineWidth = 2.5;
                            ctx.lineCap = "round";
                            ctx.beginPath();
                            ctx.strokeStyle = "#313244";
                            ctx.arc(width / 2, height / 2, 8, 0, Math.PI * 2);
                            ctx.stroke();
                            ctx.beginPath();
                            ctx.strokeStyle = root.ramUsage > 0.8 ? "#f38ba8" : "#a6e3a1";
                            ctx.arc(width / 2, height / 2, 8, -Math.PI / 2, -Math.PI / 2 - root.ramUsage * Math.PI * 2, true);
                            ctx.stroke();
                        }
                        Component.onCompleted: requestPaint()
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "memory_alt"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 12
                        color: "#cdd6f4"
                    }
                }

                Connections {
                    target: root
                    function onRamUsageChanged() { ramRing.requestPaint(); }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(root.ramUsage * 100) + "%"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: "#cdd6f4"
                }

                // Indikator baterai via UPower.displayDevice (agregat baterai).
                // percentage di Quickshell berupa desimal 0-1, jadi dikali 100.
                // state 1 = charging (enum UPower: 1 charging, 2 discharging).
                // Ikon permanen di depan persen, seperti CPU/RAM: charging pakai
                // "battery_charging_full", kalau tidak charging "battery_full".
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: UPower.displayDevice ? (UPower.displayDevice.state === 1 ? "battery_charging_full" : "battery_full") : ""
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 16
                    color: "#cdd6f4"
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: UPower.displayDevice ? Math.round(UPower.displayDevice.percentage * 100) + "%" : ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: "#cdd6f4"
                }
            }
        }
    }
}
