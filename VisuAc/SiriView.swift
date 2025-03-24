//
//  SiriView.swift
//  VisuAc
//
//  Created by Kevin Müller on 23.03.25.
//

import SwiftUI

struct SiriView: View {
    @Binding var audioURL: URL?
    
    var body: some View {
        NavigationView {
            VStack {
                MSHFSiriView(audioURL: $audioURL)
            }
            .edgesIgnoringSafeArea(.all)
        }
    }
}

// Preview
struct SiriView_Previews: PreviewProvider {
    static var previews: some View {
        SiriView(audioURL: .constant(nil))
    }
}
