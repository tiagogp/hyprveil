// Manual probe for Services/BluetoothWatch.qml.
//
//   quickshell -p tests/manual/bluetooth-watch-probe.qml
//
// Not part of tests/run.sh: it needs a Wayland display and the quickshell
// binary, neither of which the non-session gate has.
//
// It exists because the development machine has no Bluetooth adapter, so the
// debounce and battery-latch rules would otherwise ship with nothing having
// ever run them. A fake device with the same property names BlueZ exposes is
// driven through connect, a flap inside the debounce window, each battery
// threshold, a recharge, and a disconnect.
//
// Services/BluetoothWatch.qml here is a SYMLINK to the real file, so this can
// never drift into testing a stale copy.
//
// Expected output:
//   no notification at startup
//   one "Connected" despite the flap
//   one warning at 18%, silence at 17%
//   one critical at 8%, silence at 7%
//   re-arm after recharge, one warning at 15%
//   one "Disconnected"

import QtQuick
import Quickshell
import "Services"

ShellRoot {
  Item {
    id: harness
    // A stand-in for a BlueZ device: same property names the real delegate reads.
    ListModel { id: devices }
    QtObject { id: dev; property string name: "Test Headset"; property string address: "AA:BB"
               property string icon: "audio-headset"; property bool connected: false
               property real battery: 0.0 }

    BluetoothWatch {
      id: watch
      sendExternally: false           // do not spam real toasts
      devicesModel: [dev]
      onNotified: (s, b, u) => console.warn("NOTIFY[" + u + "]", s + " — " + b)
    }

    property int step: 0
    Timer {
      running: true; interval: 700; repeat: true
      onTriggered: {
        harness.step++;
        switch (harness.step) {
          case 1: console.warn("-- t=0.7s: startup done, expect NO notification yet"); break;
          case 2: console.warn("-- connect"); dev.connected = true; break;
          case 3: console.warn("-- flap: disconnect+reconnect inside the debounce"); 
                  dev.connected = false; dev.connected = true; break;
          case 6: console.warn("-- battery 35% (above threshold, expect nothing)");
                  dev.battery = 0.35; break;
          case 7: console.warn("-- battery 18% (expect ONE warning)"); dev.battery = 0.18; break;
          case 8: console.warn("-- battery 17% (already warned, expect nothing)"); dev.battery = 0.17; break;
          case 9: console.warn("-- battery 8% (expect ONE critical)"); dev.battery = 0.08; break;
          case 10: console.warn("-- battery 7% (expect nothing)"); dev.battery = 0.07; break;
          case 11: console.warn("-- recharged to 60% then back to 15% (expect re-arm + ONE warning)");
                   dev.battery = 0.60; break;
          case 12: dev.battery = 0.15; break;
          case 14: console.warn("-- disconnect"); dev.connected = false; break;
          case 17: Qt.quit(); break;
        }
      }
    }
  }
}
