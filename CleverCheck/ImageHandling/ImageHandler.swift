//
//  ImageHandler.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 09/01/2026.
//

import Foundation
import UIKit
import ObjectiveC

enum ImageHandlerError: Error, LocalizedError {
    case badServerResponse
    case cannotDecodeImage
    case userCancelled
    case presentingViewControllerMissing
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .badServerResponse:
            return "The server returned an invalid response."
        case .cannotDecodeImage:
            return "The selected image could not be decoded."
        case .userCancelled:
            return "Image selection was cancelled."
        case .presentingViewControllerMissing:
            return "Could not find a view controller to present image picker."
        case .underlying(let error):
            return error.localizedDescription
        }
    }
}

private class ImagePickerHelper: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let continuation: CheckedContinuation<UIImage, Error>
    private let imagePicker: UIImagePickerController
    private weak var presentingViewController: UIViewController?

    init(presentingViewController: UIViewController, continuation: CheckedContinuation<UIImage, Error>) {
        self.presentingViewController = presentingViewController
        self.continuation = continuation
        self.imagePicker = UIImagePickerController()
        super.init()
        imagePicker.sourceType = .photoLibrary
        imagePicker.allowsEditing = true
        imagePicker.delegate = self
    }

    func present() {
        presentingViewController?.present(imagePicker, animated: true, completion: nil)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
        picker.dismiss(animated: true) { [continuation, weak self] in
            if let image = image {
                continuation.resume(returning: image)
            } else {
                continuation.resume(throwing: ImageHandlerError.cannotDecodeImage)
            }
            // Release the helper association
            if let presenting = self?.presentingViewController {
                objc_removeAssociatedObjects(presenting)
            }
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) { [continuation, weak self] in
            continuation.resume(throwing: ImageHandlerError.userCancelled)
            if let presenting = self?.presentingViewController {
                objc_removeAssociatedObjects(presenting)
            }
        }
    }
}

struct ImageHandler {
    static func loadImage(from url: URL) async throws -> UIImage {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw ImageHandlerError.badServerResponse
            }
            guard let image = UIImage(data: data) else {
                throw ImageHandlerError.cannotDecodeImage
            }
            return image
        } catch {
            throw ImageHandlerError.underlying(error)
        }
    }

    @MainActor static func getImageFromCameraOrLibrary() async throws -> UIImage {
        guard var topVC = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow })?.rootViewController else {
            throw ImageHandlerError.presentingViewControllerMissing
        }
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        return try await withCheckedThrowingContinuation { continuation in
            let helper = ImagePickerHelper(presentingViewController: topVC, continuation: continuation)
            // Retain the helper by associating it with the presenting view controller until dismissal.
            objc_setAssociatedObject(topVC, Unmanaged.passUnretained(helper).toOpaque(), helper, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            helper.present()
        }
    }
}
