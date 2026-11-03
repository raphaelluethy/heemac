import ApplicationServices
import CoreGraphics

// Private but long-stable macOS APIs, the same ones AltTab and yabai rely on.

/// Returns the window-server id behind an accessibility window element.
@_silgen_name("_AXUIElementGetWindow")
func axWindowID(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

@_silgen_name("GetProcessForPID")
func processForPID(_ pid: pid_t, _ psn: UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus

/// Brings a process to the front with a specific window as its target.
@_silgen_name("_SLPSSetFrontProcessWithOptions")
func setFrontProcess(_ psn: UnsafeMutablePointer<ProcessSerialNumber>, _ wid: CGWindowID, _ mode: UInt32) -> CGError

@_silgen_name("SLPSPostEventRecordTo")
func postEventRecord(_ psn: UnsafeMutablePointer<ProcessSerialNumber>, _ bytes: UnsafeMutablePointer<UInt8>) -> CGError

let cpsUserGenerated: UInt32 = 0x200

/// Makes `wid` the key window of its process by posting the window server's
/// synthetic key-window events.
func makeKeyWindow(_ psn: inout ProcessSerialNumber, _ wid: CGWindowID) {
    var bytes = [UInt8](repeating: 0, count: 0xF8)
    bytes[0x04] = 0xF8
    bytes[0x3A] = 0x10
    for i in 0x20..<0x30 { bytes[i] = 0xFF }
    bytes.withUnsafeMutableBytes { $0.storeBytes(of: wid, toByteOffset: 0x3C, as: UInt32.self) }
    for phase: UInt8 in [0x01, 0x02] {
        bytes[0x08] = phase
        _ = bytes.withUnsafeMutableBufferPointer { postEventRecord(&psn, $0.baseAddress!) }
    }
}
