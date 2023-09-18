//
//  Update.swift
//  DIM
//
//  Created by G.J. Parker on 9/16/23.
//  Copyright © 2023 G.J. Parker. All rights reserved.
//

import Cocoa

class UpdateSheet: NSViewController {
    
    var myContainerViewDelegate: ViewController?
    
    @IBOutlet weak var infoLabel: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        DispatchQueue.main.async {
            self.infoLabel.stringValue = "New version is " + self.myContainerViewDelegate!.updateAvailable[0] + ", current running version " + version
        }
    }
    
    @IBAction func cancelButton(_ sender: NSButton) {
        self.dismiss(self)
        return
    }
    @IBAction func visitButton(_ sender: NSButton) {
        NSWorkspace.shared.open(URL(string: "http://www.parker9.com/desktopIconManager4.html#d")!)
        self.dismiss(self)
        return
    }
    @IBAction func downloadButtom(_ sender: NSButton) {
        if let downloadFile = URL(string: myContainerViewDelegate!.updateAvailable[1]) {
            
            /*
             let downloadFile = URL(string: updateAvailable[1])!
             let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
             let target = downloads.appendingPathComponent(downloadFolder)
             let prog = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String
             let app = target.appendingPathComponent(prog + ".app")
             */
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
            let downloadFolder = String(downloadFile.lastPathComponent.dropLast(4))
            let target = downloads.appendingPathComponent(downloadFile.lastPathComponent)
            let app = downloads.appendingPathComponent(downloadFolder) //.appendingPathComponent(prog + ".app")
            let appDelegate = NSApplication.shared.delegate as! AppDelegate
            URLCache.shared.removeAllCachedResponses()
            let getUpdate = URLSession.shared.downloadTask(with: downloadFile) { url, response, error in
                if error != nil || url == nil { self.myContainerViewDelegate!.updateError("Error connecting for download"); return }
                guard let httpResponse = response as? HTTPURLResponse, let fileURL = url, (200...299).contains(httpResponse.statusCode) else { self.myContainerViewDelegate!.updateError("Error downloading update"); return }
                do {
                    if FileManager.default.fileExists(atPath: app.path) { try? FileManager.default.trashItem(at: app, resultingItemURL: nil) }
                    if FileManager.default.fileExists(atPath: target.path) { try? FileManager.default.trashItem(at: target, resultingItemURL: nil) }
                    try FileManager.default.moveItem(at: fileURL, to: target)
                    //if FileManager.default.fileExists(atPath: app.path) { try? FileManager.default.trashItem(at: app, resultingItemURL: nil) }
                    NSWorkspace.shared.open(target)
                    self.myContainerViewDelegate!.updateDownloaded = true
                    DispatchQueue.main.async {
                        appDelegate.checkUpdateMenuItem.title = "Locate new " + (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String) + "  version..."
                        Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { (timer) in
                            if FileManager.default.fileExists(atPath: app.path) {
                                timer.invalidate()
                                try? FileManager.default.trashItem(at: target, resultingItemURL: nil)
                            }
                        }
                    }
                } catch { self.myContainerViewDelegate!.updateError("Error saving update"); return }
            }
            getUpdate.resume()
                
            
            /*
            URLSession.shared.downloadTask(with: downloadFile) { (tFileUrl, response, error) in
                if let response = response as? HTTPURLResponse, !(200...299).contains(response.statusCode) {
                    //DispatchQueue.main.async { appDelegate.checkUpdateMenuItem.title = "Error downloading update"; appDelegate.checkUpdateMenuItem.isEnabled = false }
                    appDelegate.checkUpdateMenuItem.title = "Error downloading update"; appDelegate.checkUpdateMenuItem.isEnabled = false
                    DispatchQueue.main.async { Timer.scheduledTimer(withTimeInterval: 15*1, repeats: false) { timer in
                        appDelegate.checkUpdateMenuItem.title = "Check for update..."; appDelegate.checkUpdateMenuItem.isEnabled = true } }
                        //DispatchQueue.main.async { appDelegate.checkUpdateMenuItem.title = "Check for update..."; appDelegate.checkUpdateMenuItem.isEnabled = true} }
                    return
                }
                //if error != nil { }; guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else { return }
                if let tFileUrl = tFileUrl {
                    do {
                        let data = try Data(contentsOf: tFileUrl)
                        try data.write(to: target)
                        if FileManager.default.fileExists(atPath: app.path) { try? FileManager.default.trashItem(at: app, resultingItemURL: nil) }
                        NSWorkspace.shared.open(target)
                        self.myContainerViewDelegate!.updateDownloaded = true
                        NSWorkspace.shared.selectFile(app.path, inFileViewerRootedAtPath: downloads.path)
                        DispatchQueue.main.async { appDelegate.checkUpdateMenuItem.title = "Locate new " + (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String) + "  version..." }
                        Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { (timer) in
                            if FileManager.default.fileExists(atPath: app.path) {
                                timer.invalidate()
                                try? FileManager.default.trashItem(at: target, resultingItemURL: nil)
                            }
                        }
                    } catch { }
                }
            }.resume() */
        }
        self.dismiss(self)
        return
    }
}
