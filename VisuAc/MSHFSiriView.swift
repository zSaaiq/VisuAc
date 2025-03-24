//
//  MSHFSiriView.swift
//  VisuAc
//
//  Created by Kevin Müller on 21.03.25.
//

import SwiftUI
import AVFoundation
import Accelerate

struct MSHFSiriView: View {
    @Binding var audioURL: URL?
    @State private var wavePoints: [[CGPoint]] = Array(repeating: [], count: 6)
    @State private var timer: Timer?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var fftMagnitudes: [Float] = []
    @State private var frequencyBands: [CGFloat] = Array(repeating: 0, count: 6)
    @State private var isPlaying = false
    
    // Wave appearance
    @State private var mainWaveColor: Color = .blue
    @State private var subWaveColor: Color = .green
    @State private var subSubWaveColor: Color = .purple
    @State private var backgroundColor: Color = .black
    
    @State private var subSubWaveOpacity: Double = 0.3
    @State private var subWaveOpacity: Double = 0.3
    @State private var mainWaveOpacity: Double = 0.3
    
    @State private var subSubWaveline: Double = 1.0
    @State private var subWaveline: Double = 1.5
    @State private var mainWaveline: Double = 2.0
    @State private var NoLines = true
    
    // New customization controls
    @State var showControls: Bool = false
    @State private var audioSensitivity: Double = 0.1
    @State private var randomnessAmount: Double = 0.0
    @State private var perlinNoiseAmount: Double = 1.0
    @State private var refreshRate: Double = 0.01
    
    // Wave-specific frequency band configurations
    @State private var mainWaveBand: Int = 0  // Bass (default)
    @State private var subWaveBand: Int = 2   // Mid (default)
    @State private var subSubWaveBand: Int = 5 // Presence (default)
    
    // FFT setup
    private let fftSetup: FFTSetup?
    private let log2n: UInt
    private let n: UInt
    private let halfN: UInt
    
    // Names for the frequency bands for UI
    private let bandNames = ["Bass", "Low-Mid", "Mid", "High-Mid", "Presence", "Brilliance"]
    
    init(audioURL: Binding<URL?>) {
        // Initialize the binding
        self._audioURL = audioURL
        
        // Initialize FFT parameters
        log2n = 11 // 2048 samples
        n = 1 << log2n
        halfN = n / 2
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack {
                backgroundColor.edgesIgnoringSafeArea(.all)
                
                // Render all three waves with their mirrored versions
                ForEach(0..<3) { waveIdx in
                    let index = waveIdx * 2 // Use 0, 2, 4 for the main displays
                    let (waveColor, waveOpacity, waveLineWidth) = getWaveProperties(for: waveIdx)
                    
                    // Main wave
                    SiriWaveShape(points: wavePoints[index])
                        .fill(waveColor.opacity(waveOpacity))
                        .shadow(radius: 10)
                        .zIndex(Double(2 - waveIdx)) // Proper z-ordering
                        .shadow(radius: 10)
                    
                    // Mirrored stroke (if enabled)
                    if !NoLines {
                        SiriWaveShape(points: wavePoints[index])
                            .stroke(waveColor, lineWidth: waveLineWidth)
                            .scaleEffect(y: -1)
                            .zIndex(Double(2 - waveIdx))
                    }
                }
                if showControls {
                    controlsPanel
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                        .padding()
                        .zIndex(10)
                }
                VStack{
                    Spacer()
                    HStack {
                        Button(isPlaying ? "Pause" : "Play") {
                            if isPlaying {
                                audioPlayer?.pause()
                            } else {
                                audioPlayer?.play()
                            }
                            isPlaying.toggle()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        
                        
                        Button(showControls ? "hide" : "Settings") {
                            showControls.toggle()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding(.bottom, 20)
                    
                }.zIndex(10)
            }
            .onAppear {
                loadAudio()
                setupAudioMonitoring()
                startAnimation(width: width, height: height)
            }
            .onDisappear {
                timer?.invalidate()
                audioPlayer?.stop()
            }
        }
    }
    
    // Helper function to get wave properties based on index
    func getWaveProperties(for index: Int) -> (Color, Double, Double) {
        switch index {
        case 0: // SubSubWave (Backmost)
            return (subSubWaveColor, subSubWaveOpacity, subSubWaveline)
        case 1: // SubWave (Middle)
            return (subWaveColor, subWaveOpacity, subWaveline)
        case 2: // MainWave (Frontmost)
            return (mainWaveColor, mainWaveOpacity, mainWaveline)
        default:
            return (.blue, 0.3, 1.0)
        }
    }
    
    // Get the appropriate frequency band for a wave
    func getFrequencyBandForWave(waveIndex: Int) -> CGFloat {
        let bandIndex: Int
        
        switch waveIndex {
        case 0, 1: // SubSubWave (and its mirror)
            bandIndex = subSubWaveBand
        case 2, 3: // SubWave (and its mirror)
            bandIndex = subWaveBand
        case 4, 5: // MainWave (and its mirror)
            bandIndex = mainWaveBand
        default:
            bandIndex = 0
        }
        
        return frequencyBands.isEmpty ? 1.0 : frequencyBands[bandIndex]
    }
    
    var controlsPanel: some View {
        VStack(spacing: 16) {
            Text("Audio Settings")
                .font(.headline)
                .foregroundColor(.white)
            
            // Audio sensitivity
            VStack(alignment: .leading) {
                Text("Sensitivity: \(audioSensitivity, specifier: "%.1f")")
                    .foregroundColor(.white)
                Slider(value: $audioSensitivity, in: 0.1...4.0,step: 0.01)
                    .accentColor(.blue)
            }
            
            // Frequency band settings for each wave
            Group {
                Text("Frequency bands")
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack {
                    Text("Main wave (blue):")
                        .foregroundColor(.white)
                    Picker("", selection: $mainWaveBand) {
                        ForEach(0..<bandNames.count, id: \.self) { index in
                            Text(bandNames[index]).tag(index)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .foregroundColor(.white)
                }
                
                HStack {
                    Text("Middle wave (green):")
                        .foregroundColor(.white)
                    Picker("", selection: $subWaveBand) {
                        ForEach(0..<bandNames.count, id: \.self) { index in
                            Text(bandNames[index]).tag(index)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .foregroundColor(.white)
                }
                
                HStack {
                    Text("Rear wave (purple):")
                        .foregroundColor(.white)
                    Picker("", selection: $subSubWaveBand) {
                        ForEach(0..<bandNames.count, id: \.self) { index in
                            Text(bandNames[index]).tag(index)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .foregroundColor(.white)
                }
            }
            
            // Visual settings
            VStack(alignment: .leading) {
                Text("Randomness: \(randomnessAmount, specifier: "%.1f")")
                    .foregroundColor(.white)
                Slider(value: $randomnessAmount, in: 0...1.0)
                    .accentColor(.green)
            }
            
            VStack(alignment: .leading) {
                Text("Perlin-Noise: \(perlinNoiseAmount, specifier: "%.1f")")
                    .foregroundColor(.white)
                Slider(value: $perlinNoiseAmount, in: 0...1.0)
                    .accentColor(.purple)
            }
            
            VStack(alignment: .leading) {
                Text("Show lines")
                    .foregroundColor(.white)
                Toggle("", isOn: Binding(
                    get: { !NoLines },
                    set: { NoLines = !$0 }
                ))
            }
        }
    }
    
    func loadAudio() {
        if audioURL == nil {
            // Bestehender Code für Bundle Audio
            guard let url = Bundle.main.url(forResource: "example", withExtension: "mp3") else {
                print("Audio file not found in bundle")
                return
            }
            print("Bundle Audio URL: \(url)")
            
            do {
                // Configure audio session
                try AVAudioSession.sharedInstance().setCategory(.playback)
                try AVAudioSession.sharedInstance().setActive(true)
                
                // Initialize audio player
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.prepareToPlay()
                audioPlayer?.isMeteringEnabled = true
                
                // Initialize FFT data
                fftMagnitudes = Array(repeating: 0, count: Int(halfN))
                
                // Play audio automatically
                audioPlayer?.play()
                isPlaying = true
            } catch {
                print("Error setting up the audio player: \(error)")
                isPlaying = false
            }
        } else {
            guard let url = audioURL else { return }
            
            print("Externe Audio URL: \(url)")
            
            // Wichtig: Zugriff auf die Security-Scoped URL starten
            guard url.startAccessingSecurityScopedResource() else {
                print("Error accessing security-scoped resource")
                return
            }
            
            // Nach der Verwendung den Zugriff in einem defer-Block beenden
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            do {
                // Configure audio session
                try AVAudioSession.sharedInstance().setCategory(.playback)
                try AVAudioSession.sharedInstance().setActive(true)
                
                // Initialize audio player
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                
                guard let player = audioPlayer else {
                    print("KCould not initialize AudioPlayer")
                    return
                }
                
                print("Audio Player was successfully initialized")
                print("Audio duration: \(player.duration) seconds")
                
                player.prepareToPlay()
                player.isMeteringEnabled = true
                
                // Initialize FFT data
                fftMagnitudes = Array(repeating: 0, count: Int(halfN))
                
                // Play audio automatically
                player.play()
                
                if player.isPlaying {
                    print("Audio is played")
                    isPlaying = true
                } else {
                    print("Error: Audio is not playing")
                    isPlaying = false
                }
            } catch {
                print("Error setting up the audio player: \(error)")
                isPlaying = false
            }
        }
    }
    // Hilfsfunktion zur Vermeidung von Code-Duplikation
    private func loadAudioFromURL(_ url: URL) {
        do {
            // Configure audio session
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            
            // Initialize audio player
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            
            guard let player = audioPlayer else {
                print("Could not initialize AudioPlayer")
                return
            }
            
            print("Audio Player wurde erfolgreich initialisiert")
            print("Audio Dauer: \(player.duration) Sekunden")
            
            player.prepareToPlay()
            player.isMeteringEnabled = true
            
            // Initialize FFT data
            fftMagnitudes = Array(repeating: 0, count: Int(halfN))
            
            if player.isPlaying {
                print("Audio wird wiedergegeben")
                isPlaying = true
            } else {
                print("Fehler: Audio wird nicht wiedergegeben")
                isPlaying = false
            }
        } catch {
            print("Fehler beim Einrichten des Audio Players: \(error)")
            isPlaying = false
        }
    }
    
    func setupAudioMonitoring() {
        // Setup a timer to monitor audio levels
        Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            guard let player = audioPlayer, isPlaying else { return }
            
            player.updateMeters()
            performFFTAnalysis()
        }
    }
    
    func performFFTAnalysis() {
        guard let player = audioPlayer else { return }
        
        // Create buffer for audio data
        let bufferSize = Int(n)
        var audioData = [Float](repeating: 0.0, count: bufferSize)
        // This is a simplified version that simulates FFT data using the audio meter
        let power = Float(player.averagePower(forChannel: 0))
        let normalizedPower = powf(10, 0.05 * power)
        
        // Create simulated audio data with varying frequencies based on playback position
        let position = Float(player.currentTime) / Float(player.duration)
        for i in 0..<bufferSize {
            let frequency = Float(i) * (1.0 + position * 2.0)
            audioData[i] = normalizedPower * sin(frequency)
        }
        
        // Prepare FFT input
        var realp = [Float](repeating: 0.0, count: Int(n/2))
        var imagp = [Float](repeating: 0.0, count: Int(n/2))
        
        // Create a complex split vector for the output
        var splitComplex = DSPSplitComplex(realp: &realp, imagp: &imagp)
        
        // Create a temporary buffer for the input data
        var tempBuffer = [DSPComplex](repeating: DSPComplex(), count: Int(n/2))
        
        // Copy the input data to the temporary buffer
        for i in 0..<Int(n/2) {
            tempBuffer[i].real = audioData[i * 2]
            tempBuffer[i].imag = audioData[i * 2 + 1]
        }
        
        // Convert to split complex format
        tempBuffer.withUnsafeMutableBufferPointer { tempBufferPtr in
            vDSP_ctoz(tempBufferPtr.baseAddress!, 2, &splitComplex, 1, vDSP_Length(n/2))
        }
        
        // Perform forward FFT
        vDSP_fft_zrip(fftSetup!, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))
        
        // Calculate magnitudes
        for i in 0..<Int(halfN) {
            let real = realp[i]
            let imag = imagp[i]
            fftMagnitudes[i] = sqrt(real*real + imag*imag)
        }
        
        // Divide frequency spectrum into bands - more sophisticated in real app
        // Bass, Low-Mid, Mid, High-Mid, Presence, Brilliance
        let bandRanges = [
            0..<5,      // Bass (0-100Hz)
            5..<10,     // Low-Mid (100-200Hz)
            10..<20,    // Mid (200-400Hz)
            20..<40,    // High-Mid (400-800Hz)
            40..<80,    // Presence (800-1600Hz)
            80..<160    // Brilliance (1600-3200Hz)
        ]
        
        // Calculate average magnitude for each band
        for (index, range) in bandRanges.enumerated() {
            if index < frequencyBands.count {
                let sum = range.map { fftMagnitudes[min($0, fftMagnitudes.count - 1)] }.reduce(0, +)
                let average = sum / Float(range.count)
                
                // Apply sensitivity
                let scaledValue = CGFloat(average) * CGFloat(audioSensitivity)
                frequencyBands[index] = min(max(scaledValue, 0.1), 4.0) // Clamp values
            }
        }
    }
    
    func startAnimation(width: CGFloat, height: CGFloat) {
        timer = Timer.scheduledTimer(withTimeInterval: refreshRate, repeats: true) { _ in
            // Generate new wave points for each wave
            for i in 0..<6 {
                // Get the appropriate frequency band based on which wave we're generating
                let amplitudeModifier = getFrequencyBandForWave(waveIndex: i)
                let phaseOffset = CGFloat(i) * 0.3
                
                withAnimation(.easeInOut(duration: 0.2)) {
                    wavePoints[i] = generateWavePoints(
                        width: width,
                        height: height,
                        phaseOffset: phaseOffset,
                        amplitudeModifier: amplitudeModifier,
                        waveIndex: i
                    )
                }
            }
        }
    }
    
    func generateWavePoints(width: CGFloat, height: CGFloat, phaseOffset: CGFloat, amplitudeModifier: CGFloat, waveIndex: Int) -> [CGPoint] {
        let centerY = height / 2
        var points: [CGPoint] = []
        let numberOfPoints = 100 // Increased for smoother waves
        
        // Create a time-based phase for animation
        let phase = Date().timeIntervalSince1970 * (waveIndex.isMultiple(of: 2) ? 2 : 3)
        
        // Different frequencies for different waves
        let frequency = Double(waveIndex % 3 + 2) * 0.5
        
        for i in 0..<numberOfPoints {
            let x = CGFloat(i) * (width / CGFloat(numberOfPoints - 1))
            
            // Create complex waveform by adding multiple sine waves with different phases
            var y = sin(Double(x) / Double(width) * .pi * 2 * frequency + phase + Double(phaseOffset))
            
            // Add complexity to the wave with additional harmonic components
            y += 0.5 * sin(Double(x) / Double(width) * .pi * 4 * frequency + phase * 1.5)
            y += 0.3 * sin(Double(x) / Double(width) * .pi * 3 * frequency + phase * 0.8)
            
            // Add Perlin noise (simulated here with random values that change smoothly)
            if perlinNoiseAmount > 0 {
                let noisePhase = phase * 0.1 + Double(i) * 0.05
                let perlinValue = sin(noisePhase) * cos(noisePhase * 1.3) * sin(noisePhase * 0.7)
                y += perlinValue * Double(perlinNoiseAmount) * 0.5
            }
            
            // Add random variations to make it more organic
            if randomnessAmount > 0 {
                let randomValue = Double.random(in: -1.0...1.0) * Double(randomnessAmount) * 0.3
                y += randomValue
            }
            
            // Scale the wave by the amplitude from FFT analysis
            y *= Double(amplitudeModifier)
            
            // Place wave at center of view
            let finalY = centerY + CGFloat(y) * (height * 0.15)
            
            points.append(CGPoint(x: x, y: finalY))
        }
        
        return points
    }
}

// Improved wave shape for smoother curves
struct SiriWaveShape: Shape {
    var points: [CGPoint]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }
        
        // Start at bottom-left corner to create a closed shape
        path.move(to: CGPoint(x: 0, y: rect.maxY))
        
        // Move to the first point
        path.addLine(to: CGPoint(x: points.first?.x ?? 0, y: points.first?.y ?? rect.midY))
        
        // Draw smooth curve through all points using quadratic bezier curves
        for i in 1..<points.count {
            let mid = CGPoint(x: (points[i-1].x + points[i].x) / 2, y: (points[i-1].y + points[i].y) / 2)
            path.addQuadCurve(to: mid, control: points[i-1])
        }
        
        // Add the last point if we have points
        if let lastPoint = points.last {
            path.addLine(to: lastPoint)
        }
        
        // Complete the path to create a closed shape
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        
        return path
    }
}

struct MSHFSiriView_Previews: PreviewProvider {
    static var previews: some View {
        MSHFSiriView(audioURL: .constant(nil))
            .frame(height: 400)
            .background(Color.black)
            .edgesIgnoringSafeArea(.all)
    }
}
