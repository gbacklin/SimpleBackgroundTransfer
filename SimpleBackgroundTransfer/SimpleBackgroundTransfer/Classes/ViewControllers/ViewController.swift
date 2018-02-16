/*
 File: ViewController.swift
 Abstract: Main view controller; manages a URLSession.
 Version: 1.1
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2013 Apple Inc. All Rights Reserved.
 
 */

import UIKit

private let DownloadURLString = "http://www.ehmz.org/pictures/TheStrad.jpg"
private let onceToken = NSUUID().uuidString

class ViewController: UIViewController {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var progressView: UIProgressView!
    
    var session: URLSession?
    var sessionDownloadTask: URLSessionDownloadTask?
    
    // MARK: - View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        title = "SimpleBackgroundTransfer"
        session = backgroundSession()
        
        progressView.progress = 0
        imageView.isHidden = false
        progressView.isHidden = true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - @IBAction methods
    
    @IBAction func startDownload(_ sender: UIBarButtonItem) {
        
        if sessionDownloadTask != nil {
            return
        } else {
            /*
             Create a new download task using the URL session. Tasks start in the “suspended” state; to start a task you need to explicitly call -resume on a task after creating it.
             */
            if let downloadURL = URL(string: DownloadURLString) {
                let request = URLRequest(url: downloadURL)
                sessionDownloadTask = session?.downloadTask(with: request)
                sessionDownloadTask!.resume()
                
                imageView.isHidden = true
                progressView.isHidden = false
            }
        }
    }
    
    // MARK: - Utility methods (URLSession)
    
    func backgroundSession() -> URLSession {
        var localSession: URLSession?
        
        DispatchQueue.once(token: "\(onceToken)-URLSession") {
            let configuration: URLSessionConfiguration = URLSessionConfiguration.background(withIdentifier: Bundle.main.bundleIdentifier!)
            localSession = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue())
        }
        return localSession!
    }

}

// MARK: - URLSessionDelegate

extension ViewController: URLSessionDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error == nil {
            print("Task: \(task) completed successfully")
            
            let progress = task.countOfBytesReceived / task.countOfBytesExpectedToReceive
            DispatchQueue.main.async { [weak self] in
                self!.progressView.progress = Float(progress)
            }
        } else {
            print("Task: \(task) completed with error: \(error!.localizedDescription)")
        }
        sessionDownloadTask = nil
    }
}


// MARK: - URLSessionTaskDelegate

extension ViewController: URLSessionTaskDelegate {
    /*
     If an application has received an -application:handleEventsForBackgroundURLSession:completionHandler: message, the session delegate will receive this message to indicate that all messages previously enqueued for this session have been delivered. At this time it is safe to invoke the previously stored completion handler, or to begin any internal updates that will result in invoking the completion handler.
     */

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        let appDelegate: AppDelegate = UIApplication.shared.delegate as! AppDelegate
        if (appDelegate.backgroundSessionCompletionHandler != nil) {
            let completionHandler = appDelegate.backgroundSessionCompletionHandler
            appDelegate.backgroundSessionCompletionHandler = nil
            completionHandler!()
        }
        print("All tasks are finished")
    }
}

// MARK: - URLSessionDownloadDelegate

extension ViewController: URLSessionDownloadDelegate {
    /*
     Report progress on the task.
     If you created more than one task, you might keep references to them and report on them individually.
     */

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if downloadTask == sessionDownloadTask {
            let progress = totalBytesWritten / totalBytesExpectedToWrite
            DispatchQueue.main.async { [weak self] in
                self!.progressView.progress = Float(progress)
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        /*
         The download completed, you need to copy the file at targetPath before the end of this block.
         As an example, copy the file to the Documents directory of your app.
         */
        
        let fileManager: FileManager = FileManager.default
        let urlArray = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = urlArray[0]
        let originalURL = downloadTask.originalRequest?.url
        let destinationURL = documentsDirectory.appendingPathComponent(originalURL!.lastPathComponent)
        
        // For the purposes of testing, remove any esisting file at the destination.
        do {
            try fileManager.removeItem(at: destinationURL)
        } catch {
            print("fileManager.removeItem: \(error.localizedDescription)")
        }
        
        do {
            try fileManager.copyItem(at: location, to: destinationURL)
            DispatchQueue.main.async { [weak self] in
                let image = UIImage(contentsOfFile: destinationURL.path)
                self!.imageView.image = image
                self!.imageView.isHidden = false
                self!.progressView.isHidden = true
            }
        } catch {
            print("fileManager.copyItem: \(error.localizedDescription)")
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        print("urlSession:didResumeAtOffset: session: \(session) downloadTask: \(downloadTask) fileOffset: \(fileOffset) expectedTotalBytes: \(expectedTotalBytes)")
    }
}

