//
//  HomeView.swift
//  VisuAc
//
//  Created by Kevin Müller on 23.03.25.
//

import SwiftUI

struct HomeView: View {
    @State private var selectedAudioURL: URL? = Bundle.main.url(forResource: "example1", withExtension: "mp3")
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    NavigationLink(destination: SiriView(audioURL: $selectedAudioURL)) {
                        cardView(title: "Siri View", icon: "waveform", color: .pink)
                    }
                    
                    NavigationLink(destination: MusicImport(selectedFileURL: $selectedAudioURL)) {
                        cardView(title: "Musik Import", icon: "music.note", color: .gray)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("VisuAc")
        }
    }
    
    func cardView(title: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30, height: 30)
            
            Text(title)
                .font(.headline)
        }
    }
}

#Preview {
    HomeView()
}
