//
//  ViewController.swift
//  EchbackPeripheral
//
//  Created by TechKnowledge on 2021/11/26.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController, CBPeripheralManagerDelegate {
    
    @IBOutlet weak var startAdvertizeButton: UIButton!
    @IBOutlet weak var stopAdvertizeButton: UIButton!
    
    let discoveryServiceID = CBUUID(string: "42332fe8-9915-11ea-bb37-0242ac130002")
    let primaryServiceID = CBUUID(string: "43eb0d29-4188-4c84-b1e8-73231e02af95")
    let writeCharacteristicID = CBUUID(string: "f0ab5a15-b001-4653-a248-73fd504c128f")
    let readCharacteristicID = CBUUID(string: "d0ab5a15-b002-4653-a248-73fd504c128f")
    let notifyCharacteristicID = CBUUID(string: "e0ab5a15-b003-4653-a248-73fd504c128f")
    let deviceLocalName = "ble_echo"
    
    private let queue = DispatchQueue(label: "bluetooth-discovery",
                                      qos: .background, attributes: .concurrent,
                                      autoreleaseFrequency: .workItem, target: nil)
    private var peripheralManager: CBPeripheralManager!
    private var writeCharacteristic: CBMutableCharacteristic?
    private var notifyCharacteristic: CBMutableCharacteristic?
    private var readCharacteristic: CBMutableCharacteristic?

    private var central: CBCentral?
    private var _lastData:Data!


    override func viewDidLoad() {
        super.viewDidLoad()
        self.peripheralManager = CBPeripheralManager(delegate: self, queue: queue)

    }
    
    @IBAction func onStartAdvertize() {
        self.startAdvertising()
    }
    
    @IBAction func onStopAdvertize() {
        self.stopAdvertising()
    }
    
    fileprivate func startAdvertising() {
        guard peripheralManager.state == .poweredOn else { return }
        
        if peripheralManager.isAdvertising { peripheralManager.stopAdvertising() }

        print("start advertise")
        // Start advertising with this device's name
        peripheralManager.startAdvertising(
            [CBAdvertisementDataServiceUUIDsKey: [discoveryServiceID],
             CBAdvertisementDataLocalNameKey: deviceLocalName])
    }

    fileprivate func stopAdvertising() {
        guard peripheralManager.state == .poweredOn else { return }
        if peripheralManager.isAdvertising { peripheralManager.stopAdvertising() }
    }

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        
        print("peripheralManagerDidUpdateState")


        guard peripheral.state == .poweredOn else { return }

        if peripheralManager.isAdvertising { peripheralManager.stopAdvertising() }

        writeCharacteristic = CBMutableCharacteristic(type: writeCharacteristicID,
                                                 properties: [.write],
                                                 value: nil,
                                                 permissions: .writeable)

        notifyCharacteristic = CBMutableCharacteristic(type: notifyCharacteristicID,
                                                 properties: [.notify],
                                                 value: nil,
                                                 permissions: .writeable)
        
        readCharacteristic = CBMutableCharacteristic(type: readCharacteristicID,
                                                     properties: [.read],
                                                     value: nil,
                                                     permissions: .readable)

        let service = CBMutableService(type: primaryServiceID, primary: true)
        service.characteristics = [self.readCharacteristic!, self.writeCharacteristic!, self.notifyCharacteristic!]

        peripheralManager?.add(service)

        // Start advertising as a peripheral
        let advertisementData: [String: Any] = [CBAdvertisementDataServiceUUIDsKey: [primaryServiceID]]
        peripheralManager?.startAdvertising(advertisementData)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral,
                           didSubscribeTo characteristic: CBCharacteristic) {
        print("A central has subscribed to the peripheral")
        self.central = central
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral,
                           didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("The central has unsubscribed from the peripheral")
        self.central  = nil
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        guard let request = requests.first, let data = request.value else { return }

        // Decode the message string and trigger the callback
        let message = String(decoding: data, as: UTF8.self)
        print(message)
        echoBack(data)
        _lastData = data;
    }
    
    func peripheralManager(_ peripheral:CBPeripheralManager, didReceiveRead request:CBATTRequest){
        guard let data = _lastData else {return}
        request.value = data
        peripheral.respond(to: request, withResult: CBATTError.success)
    }

    private func echoBack(_ data: Data) {
        guard let characteristic = self.notifyCharacteristic,
            let central = self.central else { return }

        peripheralManager?.updateValue(data, for: characteristic,
                                       onSubscribedCentrals: [central])
    }
}

