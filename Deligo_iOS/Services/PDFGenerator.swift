import SwiftUI
import UIKit
import PDFKit

class PDFGenerator {
    static func generateReceipt(for order: CustomerOrder) -> Data? {
        // Create a PDF document
        let pdfMetaData = [
            kCGPDFContextCreator: "DeliGo App",
            kCGPDFContextAuthor: "DeliGo",
            kCGPDFContextTitle: "Order Receipt #\(order.id)"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth = 8.5 * 72.0
        let pageHeight = 11.0 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { (context) in
            context.beginPage()
            
            // Current drawing position (y-coordinate)
            var yPosition: CGFloat = 40
            
            // Helper methods for drawing text
            func drawText(_ text: String, fontSize: CGFloat, isBold: Bool = false, rect: CGRect) {
                let font = isBold ? UIFont.boldSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize)
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .left
                let attributes = [
                    NSAttributedString.Key.font: font,
                    NSAttributedString.Key.paragraphStyle: paragraphStyle
                ]
                
                text.draw(in: rect, withAttributes: attributes)
            }
            
            func drawCenteredText(_ text: String, fontSize: CGFloat, isBold: Bool = false, y: CGFloat) {
                let font = isBold ? UIFont.boldSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize)
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .center
                let attributes = [
                    NSAttributedString.Key.font: font,
                    NSAttributedString.Key.paragraphStyle: paragraphStyle
                ]
                
                let textSize = text.size(withAttributes: attributes)
                let rect = CGRect(x: (pageWidth - textSize.width) / 2, y: y, width: textSize.width, height: textSize.height)
                
                text.draw(in: rect, withAttributes: attributes)
                
                return
            }
            
            // Draw DeliGo logo text
            drawCenteredText("DeliGo", fontSize: 28, isBold: true, y: yPosition)
            yPosition += 40
            
            // Draw Receipt title
            drawCenteredText("RECEIPT", fontSize: 18, isBold: true, y: yPosition)
            yPosition += 30
            
            // Draw order info
            let leftMargin: CGFloat = 50
            let rightColumnX: CGFloat = pageWidth - 200
            
            // Restaurant
            drawText("Restaurant:", fontSize: 12, isBold: true, rect: CGRect(x: leftMargin, y: yPosition, width: 100, height: 20))
            drawText(order.restaurantName, fontSize: 12, rect: CGRect(x: leftMargin + 110, y: yPosition, width: 300, height: 20))
            yPosition += 20
            
            // Order number
            drawText("Order #:", fontSize: 12, isBold: true, rect: CGRect(x: leftMargin, y: yPosition, width: 100, height: 20))
            drawText(order.id, fontSize: 12, rect: CGRect(x: leftMargin + 110, y: yPosition, width: 300, height: 20))
            yPosition += 20
            
            // Date
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            let dateString = dateFormatter.string(from: Date(timeIntervalSince1970: order.createdAt))
            
            drawText("Date:", fontSize: 12, isBold: true, rect: CGRect(x: leftMargin, y: yPosition, width: 100, height: 20))
            drawText(dateString, fontSize: 12, rect: CGRect(x: leftMargin + 110, y: yPosition, width: 300, height: 20))
            yPosition += 20
            
            // Status
            drawText("Status:", fontSize: 12, isBold: true, rect: CGRect(x: leftMargin, y: yPosition, width: 100, height: 20))
            drawText(order.orderStatusDisplay, fontSize: 12, rect: CGRect(x: leftMargin + 110, y: yPosition, width: 300, height: 20))
            yPosition += 20
            
            // Delivery option
            drawText("Delivery Option:", fontSize: 12, isBold: true, rect: CGRect(x: leftMargin, y: yPosition, width: 100, height: 20))
            drawText(order.deliveryOption, fontSize: 12, rect: CGRect(x: leftMargin + 110, y: yPosition, width: 300, height: 20))
            yPosition += 20
            
            // Delivery address if it's delivery
            if order.deliveryOption.lowercased() == "delivery" {
                drawText("Delivery Address:", fontSize: 12, isBold: true, rect: CGRect(x: leftMargin, y: yPosition, width: 100, height: 20))
                drawText(order.address, fontSize: 12, rect: CGRect(x: leftMargin + 110, y: yPosition, width: 300, height: 20))
                yPosition += 20
            }
            
            // Add a line
            context.cgContext.setStrokeColor(UIColor.gray.cgColor)
            context.cgContext.setLineWidth(0.5)
            context.cgContext.move(to: CGPoint(x: leftMargin, y: yPosition + 10))
            context.cgContext.addLine(to: CGPoint(x: pageWidth - leftMargin, y: yPosition + 10))
            context.cgContext.strokePath()
            yPosition += 20
            
            // Items header
            drawText("Item", fontSize: 12, isBold: true, rect: CGRect(x: leftMargin, y: yPosition, width: 200, height: 20))
            drawText("Qty", fontSize: 12, isBold: true, rect: CGRect(x: leftMargin + 200, y: yPosition, width: 50, height: 20))
            drawText("Price", fontSize: 12, isBold: true, rect: CGRect(x: leftMargin + 250, y: yPosition, width: 80, height: 20))
            drawText("Total", fontSize: 12, isBold: true, rect: CGRect(x: leftMargin + 330, y: yPosition, width: 80, height: 20))
            yPosition += 20
            
            // Add a line
            context.cgContext.setStrokeColor(UIColor.gray.cgColor)
            context.cgContext.setLineWidth(0.5)
            context.cgContext.move(to: CGPoint(x: leftMargin, y: yPosition + 5))
            context.cgContext.addLine(to: CGPoint(x: pageWidth - leftMargin, y: yPosition + 5))
            context.cgContext.strokePath()
            yPosition += 15
            
            // Item lines
            for item in order.items {
                drawText(item.name, fontSize: 11, rect: CGRect(x: leftMargin, y: yPosition, width: 200, height: 20))
                drawText("\(item.quantity)", fontSize: 11, rect: CGRect(x: leftMargin + 200, y: yPosition, width: 50, height: 20))
                drawText("$\(String(format: "%.2f", item.price))", fontSize: 11, rect: CGRect(x: leftMargin + 250, y: yPosition, width: 80, height: 20))
                drawText("$\(String(format: "%.2f", item.totalPrice))", fontSize: 11, rect: CGRect(x: leftMargin + 330, y: yPosition, width: 80, height: 20))
                yPosition += 20
            }
            
            // Add a line
            context.cgContext.setStrokeColor(UIColor.gray.cgColor)
            context.cgContext.setLineWidth(0.5)
            context.cgContext.move(to: CGPoint(x: leftMargin, y: yPosition + 5))
            context.cgContext.addLine(to: CGPoint(x: pageWidth - leftMargin, y: yPosition + 5))
            context.cgContext.strokePath()
            yPosition += 15
            
            // Totals
            drawText("Subtotal:", fontSize: 12, isBold: true, rect: CGRect(x: leftMargin + 200, y: yPosition, width: 130, height: 20))
            drawText("$\(String(format: "%.2f", order.subtotal))", fontSize: 12, rect: CGRect(x: leftMargin + 330, y: yPosition, width: 80, height: 20))
            yPosition += 20
            
            drawText("Delivery Fee:", fontSize: 12, isBold: true, rect: CGRect(x: leftMargin + 200, y: yPosition, width: 130, height: 20))
            drawText("$\(String(format: "%.2f", order.deliveryFee))", fontSize: 12, rect: CGRect(x: leftMargin + 330, y: yPosition, width: 80, height: 20))
            yPosition += 20
            
            // Add a line
            context.cgContext.setStrokeColor(UIColor.gray.cgColor)
            context.cgContext.setLineWidth(1.0)
            context.cgContext.move(to: CGPoint(x: leftMargin + 200, y: yPosition + 5))
            context.cgContext.addLine(to: CGPoint(x: pageWidth - leftMargin, y: yPosition + 5))
            context.cgContext.strokePath()
            yPosition += 15
            
            drawText("Total:", fontSize: 14, isBold: true, rect: CGRect(x: leftMargin + 200, y: yPosition, width: 130, height: 20))
            drawText("$\(String(format: "%.2f", order.total))", fontSize: 14, isBold: true, rect: CGRect(x: leftMargin + 330, y: yPosition, width: 80, height: 20))
            yPosition += 40
            
            // Thank you message
            drawCenteredText("Thank you for your order!", fontSize: 14, isBold: true, y: yPosition)
            yPosition += 20
            drawCenteredText("We appreciate your business.", fontSize: 12, y: yPosition)
            
            // Footer
            yPosition = pageHeight - 50
            drawCenteredText("DeliGo Food Delivery", fontSize: 10, y: yPosition)
            yPosition += 15
            drawCenteredText("Receipt generated on \(dateString)", fontSize: 8, y: yPosition)
        }
        
        return data
    }
    
    // Helper for saving and sharing PDFs
    static func savePDF(_ data: Data, fileName: String) -> URL? {
        // Get the documents directory
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        // Create the file URL
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        // Write the data
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error saving PDF: \(error)")
            return nil
        }
    }
} 