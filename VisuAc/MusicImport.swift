//
//  MusicImport.swift
//  VisuAc
//
//  Created by Kevin Müller on 23.03.25.
//

import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

struct MusicImport: View {
    @Binding var selectedFileURL: URL?
    @State private var audioFiles: [URL] = []
    @State private var isFileImporterPresented = false
    @State private var isHovering: String? = nil
    @Environment(\.colorScheme) var colorScheme
    
    // Farbschema für das futuristische Design
    private var primaryColor: Color { colorScheme == .dark ? Color.purple : Color.blue }
    private var secondaryColor: Color { colorScheme == .dark ? Color.indigo : Color.cyan }
    private var backgroundColor: Color { colorScheme == .dark ? Color.black : Color.white }
    
    init(selectedFileURL: Binding<URL?>) {
        self._selectedFileURL = selectedFileURL
        // Laden der gespeicherten Dateien beim Initialisieren
        _audioFiles = State(initialValue: loadSavedAudioFiles())
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Music library")
                .font(.system(.title, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        colors: [primaryColor, secondaryColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            if audioFiles.isEmpty {
                emptyLibraryView
            } else {
                audioFileListView
            }
            
            importButton
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            ZStack {
                backgroundColor
                
                // Hintergrund-Effekt
                RadialGradient(
                    gradient: Gradient(colors: [primaryColor.opacity(0.1), backgroundColor.opacity(0.0)]),
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 700
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: primaryColor.opacity(0.2), radius: 10, x: 0, y: 5)
    }
    
    // Leere Bibliothek View
    private var emptyLibraryView: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(primaryColor.opacity(0.7))
            
            Text("No audio files imported")
                .foregroundColor(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(primaryColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // Audio Files Liste
    private var audioFileListView: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(audioFiles, id: \.self) { file in
                    audioFileRow(file)
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(height: 200)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(primaryColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // Einzelne Audio-Datei Zeile
    private func audioFileRow(_ file: URL) -> some View {
        let isSelected = selectedFileURL == file
        let fileId = file.lastPathComponent
        
        return Button(action: {
            selectedFileURL = file
        }) {
            HStack {
                Image(systemName: "music.note")
                    .foregroundColor(isSelected ? secondaryColor : primaryColor.opacity(0.7))
                
                Text(file.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(secondaryColor)
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering == fileId || isSelected ?
                      primaryColor.opacity(0.1) : backgroundColor)
                .animation(.easeInOut(duration: 0.2), value: isHovering == fileId || isSelected)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? secondaryColor : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            isHovering = hovering ? fileId : nil
        }
    }
    
    // Import Button
    private var importButton: some View {
        Button(action: {
            isFileImporterPresented.toggle()
        }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text("Import music")
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [primaryColor, secondaryColor],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .clipShape(Capsule())
            .shadow(color: primaryColor.opacity(0.4), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.audio]) { result in
            switch result {
            case .success(let url):
                saveAudioFile(url: url)
            case .failure(let error):
                print("File import failed: \(error.localizedDescription)")
            }
        }
    }
    
    // Funktion zum Laden gespeicherter Audio-URLs
    private func loadSavedAudioFiles() -> [URL] {
        var loadedFiles: [URL] = []
        
        // Audio-Dateiinformationen aus UserDefaults laden
        let userDefaults = UserDefaults.standard
        
        // Zuerst Dateiinformationen laden, falls wir diese bereits nutzen
        if let savedAudioData = userDefaults.object(forKey: "savedAudioFiles") as? Data {
            if let decodedData = try? JSONDecoder().decode([AudioFileInfo].self, from: savedAudioData) {
                for fileInfo in decodedData {
                    if let bookmarkData = fileInfo.bookmarkData {
                        do {
                            var isStale = false
                            // Diese Option ist auf allen Plattformen verfügbar
                            let url = try URL(
                                resolvingBookmarkData: bookmarkData,
                                bookmarkDataIsStale: &isStale
                            )
                            
                            if isStale {
                                print("Bookmark ist veraltet: \(fileInfo.fileName)")
                            } else {
                                loadedFiles.append(url)
                            }
                        } catch {
                            print("Fehler beim Laden des Bookmarks für \(fileInfo.fileName): \(error)")
                        }
                    }
                }
            }
        }
        else {
            // Rückwärtskompatibilität für alte Methode
            let allKeys = userDefaults.dictionaryRepresentation().keys
            let bookmarkKeys = allKeys.filter { $0.hasPrefix("audioBookmark_") }
            
            for key in bookmarkKeys {
                if let bookmarkData = userDefaults.data(forKey: key) {
                    do {
                        var isStale = false
                        let url = try URL(
                            resolvingBookmarkData: bookmarkData,
                            bookmarkDataIsStale: &isStale
                        )
                        
                        if isStale {
                            print("Bookmark ist veraltet: \(key)")
                        } else {
                            loadedFiles.append(url)
                        }
                    } catch {
                        print("Fehler beim Laden des Bookmarks \(key): \(error)")
                    }
                }
            }
            
            // Konvertieren zum neuen Format
            saveAllAudioFiles(loadedFiles)
        }
        
        return loadedFiles
    }
    
    // Alle Audio-Dateien speichern
    private func saveAllAudioFiles(_ files: [URL]) {
        var audioFileInfos: [AudioFileInfo] = []
        
        for url in files {
            do {
                let bookmarkData = try url.bookmarkData(
                    options: .minimalBookmark,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                
                let fileInfo = AudioFileInfo(
                    fileName: url.lastPathComponent,
                    bookmarkData: bookmarkData
                )
                
                audioFileInfos.append(fileInfo)
            } catch {
                print("Konnte kein Bookmark erstellen für \(url.lastPathComponent): \(error)")
            }
        }
        
        if let encodedData = try? JSONEncoder().encode(audioFileInfos) {
            UserDefaults.standard.set(encodedData, forKey: "savedAudioFiles")
        }
    }
    
    // Funktion zum Speichern einer neuen Audio-URL
    private func saveAudioFile(url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            
            // URL zur Liste hinzufügen und als ausgewählt markieren
            DispatchQueue.main.async {
                audioFiles.append(url)
                selectedFileURL = url
                
                // Alle Dateien speichern
                saveAllAudioFiles(audioFiles)
            }
            
            // Für Rückwärtskompatibilität auch noch das alte Format speichern
            UserDefaults.standard.set(bookmarkData, forKey: "audioBookmark_\(url.lastPathComponent)")
        } catch {
            print("Konnte kein Bookmark erstellen: \(error)")
        }
    }
}

// Struktur für die Speicherung von Audio-Dateiinformationen
struct AudioFileInfo: Codable {
    let fileName: String
    let bookmarkData: Data?
}

// Vorschau
#Preview {
    MusicImport(selectedFileURL: .constant(nil))
        .frame(width: 350, height: 400)
        .preferredColorScheme(.dark)
}
