//
//  AppDelegate.swift
//  Alice Margatroid
//
//  Created by txx on 22/03/2017.
//  Copyright © 2017 liwushuo. All rights reserved.
//

import Cocoa
import Peertalk

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, PTChannelDelegate {

    @IBOutlet weak var window: NSWindow!
    
    @IBOutlet weak var imageView: NSImageView!
    private let notConnectedQueue: DispatchQueue = DispatchQueue(label: "notConnectedQueue")
    
    private var connectingToDeviceID: NSNumber? = nil
    private var connectedDeviceID: NSNumber? = nil
    private var notConnectedChannel = false
    private var connectedChannel: PTChannel? = nil
    

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        startListeningForDevices()
        ping()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func startListeningForDevices () {
        let nc = NotificationCenter.default
        
        nc.addObserver(forName: NSNotification.Name.PTUSBDeviceDidAttach,
                       object: PTUSBHub.shared(),
                       queue: nil) { notification in
                        if let userInfo = notification.userInfo, let deviceID = userInfo["DeviceID"] as? NSNumber {
                            
                            self.notConnectedQueue.async {
                                var flag = self.connectingToDeviceID == nil
                                
                                if let currentID = self.connectingToDeviceID {
                                    flag = flag || deviceID.isEqual(to: currentID)
                                }
                                
                                if flag {
                                    self.disconnectFromCurrentChannel()
                                    self.connectingToDeviceID = deviceID
                                    self.enqueueConnectToUSBDevice()
                                }
                            }
                            
                        }
        }
        
        nc.addObserver(forName: NSNotification.Name.PTUSBDeviceDidDetach,
                       object: PTUSBHub.shared(),
                       queue: nil) { notification in
                        if let userInfo = notification.userInfo, let deviceID = userInfo["DeviceID"] as? NSNumber {
                            
                            if let currentID = self.connectingToDeviceID, currentID.isEqual(to: deviceID) {
                                self.connectingToDeviceID = nil
                                
                                if self.connectedChannel != nil {
                                    self.connectedChannel = nil
                                }
                            }
                        }
        }
    }
    
    func disconnectFromCurrentChannel() {
        
        self.connectedChannel?.close()
        self.connectedChannel = nil
        self.connectedDeviceID = nil
        
    }
    
    @objc func enqueueConnectToUSBDevice() {
        self.notConnectedQueue.async {
            DispatchQueue.main.async {
                self.connectToUSBDevice()
            }
        }
    }
    
    func connectToUSBDevice() {
        let channel = PTChannel(delegate: self)
        
        channel?.userInfo = connectingToDeviceID
        
        channel?.connect(toPort: 2345, overUSBHub: PTUSBHub.shared(), deviceID: connectingToDeviceID){ error in
            if let error = error as? NSError {
                
                if (error.domain == PTUSBHubErrorDomain && (UInt32(error.code) == PTUSBHubErrorConnectionRefused.rawValue)) {
                    NSLog("Failed to connect to device")
                } else {
                    NSLog("Failed to connect to 127.0.0.1:2345: %s", error.localizedDescription);
                }
                
                if let a = channel?.userInfo as? NSNumber, let b = self.connectingToDeviceID, a == b  {
                    self.perform(#selector(self.enqueueConnectToUSBDevice), with: nil, afterDelay: 1)
                }
            } else {
                
                self.connectedDeviceID = self.connectingToDeviceID
                self.connectedChannel = channel
            }
            
            
        }
    }
    
    func pong() {
        NSLog("Received Pong")
    }
    
    func ping() {
        if let connectedChannel = connectedChannel, let pro = connectedChannel.protocol {
            connectedChannel.sendFrame(ofType: 102, tag: pro.newTag(), withPayload: nil, callback: { err in
                DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                    self.ping()
                })
                NSLog("Sent Ping")
            })
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                self.ping()
            })
        }
    }
    
    func ioFrameChannel(_ channel: PTChannel!, shouldAcceptFrameOfType type: UInt32, tag: UInt32, payloadSize: UInt32) -> Bool {
        return true
    }
    
    func ioFrameChannel(_ channel: PTChannel!, didEndWithError error: Error!) {
        
    }
    
    func ioFrameChannel(_ channel: PTChannel!, didReceiveFrameOfType type: UInt32, tag: UInt32, payload: PTData!) {
        if (type == 103) {
            pong()
        }
        
        if (type == 104) {
            
            if let data = NSData.init(contentsOfDispatchData: payload.dispatchData), let image = NSImage(data: data as Data) {
                DispatchQueue.main.async {
                    self.imageView.image = image
                }
            }
        }
    }
    
    func ioFrameChannel(_ channel: PTChannel!, didAcceptConnection otherChannel: PTChannel!, from address: PTAddress!) {
        
    }
}

