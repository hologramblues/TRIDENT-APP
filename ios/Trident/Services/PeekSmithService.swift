import Foundation
import Combine
import CoreBluetooth

// ————————————————————— PeekSmith 3 (CoreBluetooth) —————————————————————
// UUIDs et protocole issus de CLAUDE-HUB-INTEGRATION.md :
// - scan par préfixe de nom "PeekSmith"
// - service HM-10 FFE0, characteristic données FFE1 (notify + write)
// - service alternatif 8D53DC1D-… (char notify pour lire, char write pour écrire)
// - notifications UTF-8 entrantes : "isb0,click" / "isb1,click" / "isb2,click"
// - écriture : texte UTF-8 brut (ex. "E (7)", "= SCORPION")
//
// DISCRÉTION : le CBCentralManager n'est instancié que dans start() — jamais appelé
// au lancement de l'app. La popup Bluetooth n'apparaît qu'au premier psConnect
// (déclenché par l'utilisateur depuis les réglages du hub).

protocol PeekSmithTransport {
    var isConnected: Bool { get }
    func send(_ line: String)
}

final class PeekSmithService: NSObject, ObservableObject, PeekSmithTransport {
    static let shared = PeekSmithService() // partagé hub (pont) / Trident (cycle, plus tard)

    private static let hm10Service = CBUUID(string: "FFE0")
    private static let hm10Char = CBUUID(string: "FFE1")
    private static let altService = CBUUID(string: "8D53DC1D-1DB7-4CD3-868B-8A527460AA84")

    @Published private(set) var isConnected = false
    @Published private(set) var deviceName: String?
    /// Bouton pressé sur le PeekSmith : 0 = passer, 1 = OUI, 2 = NON.
    var onButton: ((Int) -> Void)?
    /// Changement d'état de connexion (relayé au hub via psStatus).
    var onStatusChange: ((Bool, String?) -> Void)?

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var writeChar: CBCharacteristic?
    private var notifyChar: CBCharacteristic?

    /// Démarre scan + connexion. Première instanciation = popup Bluetooth iOS.
    func start() {
        if central == nil {
            central = CBCentralManager(delegate: self, queue: .main)
        } else if central?.state == .poweredOn, !isConnected {
            scan()
        }
    }

    func send(_ line: String) {
        guard isConnected, let peripheral, let writeChar else { return }
        let type: CBCharacteristicWriteType =
            writeChar.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        peripheral.writeValue(Data(line.utf8), for: writeChar, type: type)
    }

    private func scan() {
        // scan sans filtre de service : le PeekSmith s'identifie par son nom
        central?.scanForPeripherals(withServices: nil, options: nil)
    }

    private func setConnected(_ ok: Bool) {
        isConnected = ok
        onStatusChange?(ok, deviceName)
    }
}

extension PeekSmithService: CBCentralManagerDelegate, CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            if !isConnected { scan() }
        } else {
            setConnected(false)
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover p: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        let nom = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? p.name ?? ""
        guard nom.hasPrefix("PeekSmith") else { return }
        peripheral = p
        deviceName = nom
        central.stopScan()
        central.connect(p)
    }

    func centralManager(_ central: CBCentralManager, didConnect p: CBPeripheral) {
        p.delegate = self
        p.discoverServices([Self.hm10Service, Self.altService])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) {
        setConnected(false)
        scan()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
        writeChar = nil
        notifyChar = nil
        setConnected(false)
        scan() // reconnexion auto (le PS peut s'éteindre/rallumer en cours de set)
    }

    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        for s in p.services ?? [] where s.uuid == Self.hm10Service || s.uuid == Self.altService {
            p.discoverCharacteristics(nil, for: s)
        }
    }

    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor s: CBService, error: Error?) {
        for c in s.characteristics ?? [] {
            if s.uuid == Self.hm10Service, c.uuid == Self.hm10Char {
                // HM-10 : une seule characteristic pour lire ET écrire
                writeChar = c
                notifyChar = c
            } else if s.uuid == Self.altService {
                // service alternatif : char notify pour lire, char write pour écrire
                if c.properties.contains(.notify), notifyChar == nil { notifyChar = c }
                if (c.properties.contains(.write) || c.properties.contains(.writeWithoutResponse)), writeChar == nil { writeChar = c }
            }
        }
        if let notifyChar { p.setNotifyValue(true, for: notifyChar) }
        if writeChar != nil { setConnected(true) }
    }

    func peripheral(_ p: CBPeripheral, didUpdateValueFor c: CBCharacteristic, error: Error?) {
        guard let data = c.value, let texte = String(data: data, encoding: .utf8) else { return }
        // boutons du PS : isb0=passer, isb1=OUI, isb2=NON
        if texte.contains("isb1,click") { onButton?(1) }
        else if texte.contains("isb2,click") { onButton?(2) }
        else if texte.contains("isb0,click") { onButton?(0) }
    }
}
