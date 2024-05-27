//
//  InferenceProgressView.swift
//  PianoTranscriber
//
//  Created by Kasper Nielsen on 27/05/2024.
//

import SwiftUI

enum InferenceProgress {
    case notRunning
    case loadingAudio
    case inferring(Double)
    case stiching
    case eventizing
}

struct InferenceProgressView: View {
    let progress: InferenceProgress
    
    var body: some View {
        VStack {
            Spacer()
            switch progress {
            case .notRunning:
                Text("Not running")
            case .loadingAudio:
                Text("Loading audio...")
            case .inferring(let percentage):
                Text("Inferring \(percentage * 100)%")
            case .stiching:
                Text("Stitching...")
            case .eventizing:
                Text("Eventizing...")
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground).opacity(0.8))
        .edgesIgnoringSafeArea(.all)
    }
}

#Preview {
    @State var progress = InferenceProgress.loadingAudio

    return InferenceProgressView(progress: progress)
}
