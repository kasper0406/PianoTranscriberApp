//
//  FileExporterView.swift
//  PianoTranscriber
//
//  Created by Kasper Nielsen on 10/06/2024.
//

import UIKit
import SwiftUI

struct FileExporterViewController: UIViewControllerRepresentable {

    var items: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: UIViewControllerRepresentableContext<FileExporterViewController>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<FileExporterViewController>) {}

}
