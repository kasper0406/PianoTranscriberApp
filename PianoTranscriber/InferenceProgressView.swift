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
                Image("SmileNoEars")
                    .resizable()
                    .scaledToFit()
                    .padding()
            case .inferring(let percentage):
                let maxInferImgCount = 13
                let imgCount = Int(round(percentage * Double(maxInferImgCount)))
                Image("CatInfer_\(imgCount)_\(maxInferImgCount)")
                    .resizable()
                    .scaledToFit()
                    .padding()
            default:
                Image("SmileWithEars")
                    .resizable()
                    .scaledToFit()
                    .padding()
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
        .edgesIgnoringSafeArea(.all)
    }
}
