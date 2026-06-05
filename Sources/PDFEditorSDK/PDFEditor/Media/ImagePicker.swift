import SwiftUI
import UIKit

enum ImagePickerSource {
    case camera
    case photoLibrary

    var uiSourceType: UIImagePickerController.SourceType {
        switch self {
        case .camera:
            return UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        case .photoLibrary:
            return .photoLibrary
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let allowsEditing: Bool
    let onImagePicked: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage?) -> Void

        init(onImagePicked: @escaping (UIImage?) -> Void) {
            self.onImagePicked = onImagePicked
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage else {
                onImagePicked(nil)
                picker.dismiss(animated: true)
                return
            }

            let cropVC = ImageCropViewController(image: image)
            let nav = UINavigationController(rootViewController: cropVC)
            nav.modalPresentationStyle = .fullScreen
            nav.navigationBar.barStyle = .black
            nav.navigationBar.tintColor = .white
            nav.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]

            cropVC.onConfirm = { [weak picker] cropped in
                picker?.presentingViewController?.dismiss(animated: true)
                self.onImagePicked(cropped)
            }
            cropVC.onCancel = { [weak picker] in
                picker?.presentingViewController?.dismiss(animated: true)
                self.onImagePicked(nil)
            }

            picker.present(nav, animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImagePicked(nil)
            picker.dismiss(animated: true)
        }
    }
}
