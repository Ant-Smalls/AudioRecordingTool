//
//  ViewController.swift
//  AudioPlayer
//
//  Created by Anthony Smaldore on 10/30/24.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    // UI Elements
    @IBOutlet weak var transcriptionTextView: UITextView!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var clearButton: UIButton!
    
    // Audio and AssemblyAI properties
    var isRecording = false
    var audioEngine = AVAudioEngine()
    var assemblyAIClient: AssemblyAIWebSocketClient?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Initial UI setup
        clearButton.isHidden = true
        transcriptionTextView.text = ""
    }
    
    @IBAction func recordButtonTapped(_ sender: UIButton) {
        print("recordButtonTapped called")
        if !isRecording {
            // Start recording
            startRecording()
            recordButton.setTitle("Stop Recording", for: .normal)
            isRecording = true
            clearButton.isHidden = true
        } else {
            // Stop recording
            stopRecording()
            recordButton.setTitle("Start Recording", for: .normal)
            isRecording = false
            clearButton.isHidden = false
        }
    }
    
    @IBAction func clearButtonTapped(_ sender: UIButton) {
        // Clear the transcription text
        transcriptionTextView.text = ""
        clearButton.isHidden = true
    }
    
    func startRecording() {
        // Initialize AssemblyAI client
        assemblyAIClient = AssemblyAIWebSocketClient(audioSampleRate: 16000)
        assemblyAIClient?.connect()
        assemblyAIClient?.onTranscriptionReceived = { [weak self] text in
            print("Transcription received: \(text)")
            DispatchQueue.main.async {
                self?.transcriptionTextView.text += text + " "
                // Scroll to the bottom
                if let textView = self?.transcriptionTextView {
                    let bottom = NSMakeRange(textView.text.count - 1, 1)
                    textView.scrollRangeToVisible(bottom)
                }
            }
        }
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to set audio session category: \(error)")
        }
        
        // Setup audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        let downsampleFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!
        
        // Install tap on input node to capture audio
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, when) in
            guard let self = self else { return }
            // Downsample and send audio buffer to AssemblyAI
            if let downsampledBuffer = self.downSample(buffer: buffer, to: downsampleFormat) {
                print("Captured audio buffer with frame length: \(buffer.frameLength)")
                self.assemblyAIClient?.send(pcmBuffer: downsampledBuffer)
            } else {
                print("Downsampling failed")
            }
        }
        
        // Start the audio engine
        do {
            audioEngine.prepare()
            try audioEngine.start()
            print("Audio engine started successfully")
        } catch {
            print("Failed to start audio engine: \(error)")
            return
        }
    }
    
    func stopRecording() {
        // Stop the audio engine and remove tap
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        assemblyAIClient?.disconnect()
        assemblyAIClient = nil
    }
    
    func downSample(buffer: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let converter = AVAudioConverter(from: buffer.format, to: format) else {
            print("Error creating audio converter")
            return nil
        }
        let frameCapacity = AVAudioFrameCount(format.sampleRate / buffer.format.sampleRate * Double(buffer.frameLength))
        guard let downsampledBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            print("Error creating downsampled buffer")
            return nil
        }
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        converter.convert(to: downsampledBuffer, error: &error, withInputFrom: inputBlock)
        if let error = error {
            print("Error during audio conversion: \(error)")
            return nil
        }
        if let error = error {
            print("Error during audio conversion: \(error)")
            return nil
        } else {
            print("Audio conversion successful, frame length: \(downsampledBuffer.frameLength)")
        }
        return downsampledBuffer
    }
}
