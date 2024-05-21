//
//  AudioFilePicker.swift
//  PianoTranscriber
//
//  Created by Kasper Nielsen on 21/05/2024.
//

import Foundation
import SwiftUI
import MobileCoreServices
import UniformTypeIdentifiers

struct AudioFilePicker: UIViewControllerRepresentable {
    var onFilePicked: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.audio], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: AudioFilePicker
        
        init(_ picker: AudioFilePicker) {
            self.parent = picker
        }
        
        func audioPicker(_ controller: UIDocumentPickerViewController, pickedDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onFilePicked(url)
        }
    }
}
