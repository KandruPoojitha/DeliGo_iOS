import SwiftUI
import UIKit
import PDFKit

struct OrderReceiptView: View {
    let order: CustomerOrder
    @Environment(\.presentationMode) var presentationMode
    @State private var pdfURL: URL?
    @State private var isGeneratingPDF = true
    @State private var showShareSheet = false
    
    var body: some View {
        NavigationView {
            VStack {
                if isGeneratingPDF {
                    ProgressView("Generating receipt...")
                        .padding()
                } else if let pdfURL = pdfURL {
                    PDFKitView(url: pdfURL)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                } else {
                    Text("Failed to generate receipt")
                        .foregroundColor(.red)
                        .padding()
                }
                
                if !isGeneratingPDF {
                    Button(action: {
                        showShareSheet = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Receipt")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(hex: "F4A261"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    .disabled(pdfURL == nil)
                    .padding(.bottom)
                }
            }
            .navigationTitle("Order Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.primary)
                }
            )
            .onAppear {
                generatePDF()
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = pdfURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }
    
    private func generatePDF() {
        DispatchQueue.global(qos: .userInitiated).async {
            if let pdfData = PDFGenerator.generateReceipt(for: order) {
                let fileName = "DeliGo-Receipt-\(order.id).pdf"
                let url = PDFGenerator.savePDF(pdfData, fileName: fileName)
                
                DispatchQueue.main.async {
                    self.pdfURL = url
                    self.isGeneratingPDF = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isGeneratingPDF = false
                }
            }
        }
    }
}

// PDF view wrapper
struct PDFKitView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.displayMode = .singlePageContinuous
        pdfView.autoScales = true
        pdfView.displayDirection = .vertical
        pdfView.document = PDFDocument(url: url)
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = PDFDocument(url: url)
    }
}

// Share sheet implementation
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Nothing to do here
    }
} 