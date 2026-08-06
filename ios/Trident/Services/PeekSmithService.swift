import Foundation
import CoreBluetooth

// ————————————————————— PeekSmith (squelette v2) —————————————————————
// NON UTILISÉ EN V1. Le CBCentralManager n'est instancié que dans start(), qui n'est
// jamais appelé : l'instancier déclencherait la popup d'autorisation Bluetooth au
// premier lancement (interdit — discrétion scénique).
// À brancher en v2 avec le protocole réel du PeekSmith (UUIDs à renseigner, tests
// sur iPhone réel — le Bluetooth ne fonctionne pas dans le simulateur).

protocol PeekSmithTransport {
    var isConnected: Bool { get }
    func send(_ line: String)
}

final class PeekSmithService: NSObject, PeekSmithTransport {
    // TODO v2 : remplacer par les UUIDs réels du PeekSmith (service UART + characteristic d'écriture)
    private static let serviceUUID = CBUUID(string: "0000FFE0-0000-1000-8000-00805F9B34FB")
    private static let writeUUID = CBUUID(string: "0000FFE1-0000-1000-8000-00805F9B34FB")

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var writeChar: CBCharacteristic?
    private(set) var isConnected = false

    /// À appeler en v2 seulement — première instanciation = popup Bluetooth.
    func start() {
        if central == nil { central = CBCentralManager(delegate: self, queue: .main) }
    }

    func send(_ line: String) {
        guard isConnected, let peripheral, let writeChar else { return }
        peripheral.writeValue(Data(line.utf8), for: writeChar, type: .withoutResponse)
    }
}

extension PeekSmithService: CBCentralManagerDelegate, CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else { isConnected = false; return }
        central.scanForPeripherals(withServices: [Self.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didDiscover p: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        peripheral = p
        central.stopScan()
        central.connect(p)
    }

    func centralManager(_ central: CBCentralManager, didConnect p: CBPeripheral) {
        p.delegate = self
        p.discoverServices([Self.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
        isConnected = false
        writeChar = nil
        central.scanForPeripherals(withServices: [Self.serviceUUID]) // reconnexion auto
    }

    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        guard let s = p.services?.first(where: { $0.uuid == Self.serviceUUID }) else { return }
        p.discoverCharacteristics([Self.writeUUID], for: s)
    }

    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor s: CBService, error: Error?) {
        writeChar = s.characteristics?.first(where: { $0.uuid == Self.writeUUID })
        isConnected = writeChar != nil
    }
}
