//
//  AssemblyAIWebSocket.swift
//  AudioPlayer
//
//  Created by Yusuke Abe on 2024/11/09.
//

import AVFoundation
import Foundation

class AssemblyAIWebSocketClient: ObservableObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private let urlSession: URLSession
    private let apiKey: String = "dac8d7b59ac9423e8b02f598509188b1"
    private let audioSampleRate: Int

    // Closure to handle received transcriptions
    var onTranscriptionReceived: ((String) -> Void)?
    
    init(audioSampleRate: Int = 16000) {
        self.audioSampleRate = audioSampleRate
        self.urlSession = URLSession(configuration: .default)
        print("AssemblyAIWebSocketClient initialized with sample rate: \(audioSampleRate)")
    }

    func connect() {
        print("Attempting to connect to AssemblyAI")

        let url = URL(string: "wss://api.assemblyai.com/v2/realtime/ws?sample_rate=\(audioSampleRate)")!
        var request = URLRequest(url: url)
        // Set the Authorization header with your API key
        request.addValue(apiKey, forHTTPHeaderField: "Authorization")

        webSocketTask = urlSession.webSocketTask(with: request)
        webSocketTask?.resume()
        listenForMessages()
    }

    func send(pcmBuffer: AVAudioPCMBuffer) {
        guard let audioBuffer = pcmBuffer.int16ChannelData?[0] else {
            print("No data in PCM buffer")
            return
        }

        let frameLength = Int(pcmBuffer.frameLength)
        let data = Data(bytes: audioBuffer, count: frameLength * 2) // 16-bit samples

        // Convert audio data to base64 encoded string
        let base64EncodedString = data.base64EncodedString()
        // Send as a string message in JSON format
        let message = URLSessionWebSocketTask.Message.string("{\"audio_data\": \"\(base64EncodedString)\"}")

        webSocketTask?.send(message) { error in
            if let error = error {
                print("Error sending PCM buffer: \(error)")
            }
        }
    }

    func disconnect() {
        print("Disconnecting from AssemblyAI")
        // Send a termination message before closing the connection
        let terminateMessage = URLSessionWebSocketTask.Message.string("{\"terminate_session\": true}")
        webSocketTask?.send(terminateMessage) { [weak self] error in
            if let error = error {
                print("Error sending termination message: \(error)")
            }
            self?.webSocketTask?.cancel(with: .normalClosure, reason: nil)
        }
    }

    private func listenForMessages() {
        print("Listening for messages from AssemblyAI")
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .failure(let error):
                print("Error receiving message: \(error)")
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleReceivedMessage(text)
                case .data(let data):
                    print("Received data: \(data)")
                @unknown default:
                    break
                }
                // Continue listening for messages
                self?.listenForMessages()
            }
        }
    }

    // Function to handle the received message
    private func handleReceivedMessage(_ text: String) {
        print("Received message from WebSocket: \(text)")
        guard let data = text.data(using: .utf8) else {
            print("Error converting text to data")
            return
        }
        do {
            guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                print("Error casting JSON object to [String: Any]")
                return
            }
            // Extract the message type
            guard let messageType = json["message_type"] as? String else {
                print("Error extracting 'message_type' from JSON")
                return
            }

            switch messageType {
            case "SessionBegins":
                print("Session has begun.")
                // Handle session start if needed
            case "PartialTranscript", "FinalTranscript":
                // Extract the 'text' field if it exists
                if let transcriptText = json["text"] as? String {
                    if !transcriptText.isEmpty {
                        print("Transcription received: \(transcriptText)")
                        DispatchQueue.main.async { [weak self] in
                            self?.onTranscriptionReceived?(transcriptText)
                        }
                    } else {
                        print("Received empty transcript.")
                    }
                } else {
                    print("No 'text' field in transcript message.")
                }
            case "SessionEnds":
                print("Session has ended.")
                // Handle session end if needed
            case "Error":
                if let errorMessage = json["error"] as? String {
                    print("AssemblyAI Error: \(errorMessage)")
                } else {
                    print("Received error message without 'error' field.")
                }
            default:
                print("Received unhandled message type: \(messageType)")
            }
        } catch {
            print("Error parsing JSON: \(error.localizedDescription)")
        }
    }
}
