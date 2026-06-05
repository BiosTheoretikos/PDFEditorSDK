//
//  PDFFormViewModel+ImagePicking.swift
//  PDFEditorSDK
//

import PDFKit
import UIKit

@MainActor
extension PDFFormViewModel {
    func presentFormWidgetImageSourceChoice(pageIndex: Int, annotation: PDFAnnotation) {
        pendingFormWidgetPageIndex = pageIndex
        pendingFormWidgetAnnotation = annotation
        showFormWidgetImageSourceDialog = true
    }

    func cancelPendingFormWidgetImagePick() {
        pendingFormWidgetPageIndex = nil
        pendingFormWidgetAnnotation = nil
        imagePickIsForFormWidget = false
    }

    func beginFormWidgetImagePickFromCamera() {
        imagePickIsForFormWidget = true
        showFormWidgetImageSourceDialog = false
    }

    func beginFormWidgetImagePickFromLibrary() {
        imagePickIsForFormWidget = true
        showFormWidgetImageSourceDialog = false
    }

    func handleImagePickedFromSheet(_ image: UIImage?) {
        if imagePickIsForFormWidget {
            let pageIndex = pendingFormWidgetPageIndex
            let annotation = pendingFormWidgetAnnotation
            imagePickIsForFormWidget = false
            pendingFormWidgetPageIndex = nil
            pendingFormWidgetAnnotation = nil
            guard let image,
                  let pageIndex,
                  let annotation,
                  let page = pdfDocument?.page(at: pageIndex) else { return }
            pdfView?.addOverlayImage(image, forFormWidget: annotation, on: page)
            return
        }
        if let image {
            addImage(image)
        }
    }
}
