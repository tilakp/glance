import CoreMediaIO
import Foundation

/// Reports whether any camera on this Mac is currently streaming.
///
/// Reads the CoreMediaIO hardware layer's per-device "is running somewhere"
/// flag. This inspects device state only: it needs no camera (TCC) permission,
/// never opens a capture session, and cannot see image data.
enum CameraMonitor {

    static func isCameraInUse() -> Bool {
        deviceIDs().contains(where: isRunning)
    }

    private static func deviceIDs() -> [CMIOObjectID] {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )

        var dataSize: UInt32 = 0
        var dataUsed: UInt32 = 0
        var status = CMIOObjectGetPropertyDataSize(
            CMIOObjectID(kCMIOObjectSystemObject), &address, 0, nil, &dataSize)
        guard status == noErr, dataSize > 0 else { return [] }

        let count = Int(dataSize) / MemoryLayout<CMIOObjectID>.size
        var ids = [CMIOObjectID](repeating: 0, count: count)
        status = CMIOObjectGetPropertyData(
            CMIOObjectID(kCMIOObjectSystemObject), &address, 0, nil,
            dataSize, &dataUsed, &ids)
        guard status == noErr else { return [] }
        return ids
    }

    private static func isRunning(_ device: CMIOObjectID) -> Bool {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
        )

        var running: UInt32 = 0
        var dataUsed: UInt32 = 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        let status = CMIOObjectGetPropertyData(
            device, &address, 0, nil, size, &dataUsed, &running)
        return status == noErr && running != 0
    }
}
