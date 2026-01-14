//
//  ImageHandler.swift
//  CleverCheck
//
//  Created by Ulrich Rüth on 09/01/2026.
//

import Foundation
import UIKit
import ObjectiveC
import Photos
import ImageIO

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

    init(presentingViewController: UIViewController, sourceType: UIImagePickerController.SourceType, continuation: CheckedContinuation<UIImage, Error>) {
        self.presentingViewController = presentingViewController
        self.continuation = continuation
        self.imagePicker = UIImagePickerController()
        super.init()
        imagePicker.sourceType = sourceType
        imagePicker.allowsEditing = false
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

// New: container for image + metadata
struct ImageWithMetadata {
    let image: UIImage
    let creationDate: Date?
    let metadata: [String: Any]?
}

// New: helper that extracts metadata when picking an image
private class ImagePickerHelperWithMetadata: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let continuation: CheckedContinuation<ImageWithMetadata, Error>
    private let imagePicker: UIImagePickerController
    private weak var presentingViewController: UIViewController?

    init(presentingViewController: UIViewController, sourceType: UIImagePickerController.SourceType, continuation: CheckedContinuation<ImageWithMetadata, Error>) {
        self.presentingViewController = presentingViewController
        self.continuation = continuation
        self.imagePicker = UIImagePickerController()
        super.init()
        imagePicker.sourceType = sourceType
        imagePicker.allowsEditing = false
        imagePicker.delegate = self
    }

    func present() {
        presentingViewController?.present(imagePicker, animated: true, completion: nil)
    }

    private func parseMetadataFromImageData(_ data: Data) -> [String: Any]? {
        let cfData = data as CFData
        guard let source = CGImageSourceCreateWithData(cfData, nil) else { return nil }
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else { return nil }
        return props
    }

    private func parseEXIFDate(_ props: [String: Any]) -> Date? {
        if let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            let dateKeys = [kCGImagePropertyExifDateTimeOriginal as String, kCGImagePropertyExifDateTimeDigitized as String, kCGImagePropertyExifDateTimeOriginal as String]
            for key in dateKeys {
                if let dateString = exif[key] as? String {
                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                    if let d = formatter.date(from: dateString) {
                        return d
                    }
                }
            }
        }
        return nil
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage

        // We'll dismiss first, then fetch metadata (if asynchronous) and resume continuation once ready.
        picker.dismiss(animated: true) { [continuation, weak self] in
            guard let self = self else { return }
            guard let image = image else {
                continuation.resume(throwing: ImageHandlerError.cannotDecodeImage)
                if let presenting = self.presentingViewController {
                    objc_removeAssociatedObjects(presenting)
                }
                return
            }

            // 1) If camera capture, metadata may be present in .mediaMetadata
            if let mediaMetadata = info[.mediaMetadata] as? [String: Any] {
                var creationDate: Date? = nil
                if let exif = mediaMetadata["{Exif}"] as? [String: Any], let dateString = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                    creationDate = formatter.date(from: dateString)
                }
                continuation.resume(returning: ImageWithMetadata(image: image, creationDate: creationDate, metadata: mediaMetadata))
                if let presenting = self.presentingViewController {
                    objc_removeAssociatedObjects(presenting)
                }
                return
            }

            // 2) If the picker provided a PHAsset (photo library), request the image data to read metadata and creation date
            if #available(iOS 11.0, *), let asset = info[.phAsset] as? PHAsset {
                // Use PHImageManager to get data + properties
                let options = PHImageRequestOptions()
                options.isSynchronous = false
                options.isNetworkAccessAllowed = true
                options.version = .current
                PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, dataUTI, orientation, infoDict in
                    var metadata: [String: Any]? = nil
                    var creationDate: Date? = asset.creationDate
                    if let data = data {
                        if let props = self.parseMetadataFromImageData(data) {
                            metadata = props
                            if creationDate == nil {
                                creationDate = self.parseEXIFDate(props)
                            }
                        }
                    }
                    continuation.resume(returning: ImageWithMetadata(image: image, creationDate: creationDate, metadata: metadata))
                    if let presenting = self.presentingViewController {
                        objc_removeAssociatedObjects(presenting)
                    }
                }
                return
            }

            // 3) If we have a file URL for the image, read properties via ImageIO
            if let imageURL = info[.imageURL] as? URL {
                var metadata: [String: Any]? = nil
                if let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil), let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
                    metadata = props
                }
                var creationDate: Date? = nil
                if let props = metadata {
                    creationDate = self.parseEXIFDate(props)
                }
                continuation.resume(returning: ImageWithMetadata(image: image, creationDate: creationDate, metadata: metadata))
                if let presenting = self.presentingViewController {
                    objc_removeAssociatedObjects(presenting)
                }
                return
            }

            // 4) Fallback: no metadata available
            continuation.resume(returning: ImageWithMetadata(image: image, creationDate: nil, metadata: nil))
            if let presenting = self.presentingViewController {
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

    @MainActor static func getImageWithMetadataFromCameraOrLibrary(_ sourceType: UIImagePickerController.SourceType) async throws -> ImageWithMetadata {
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
            let helper = ImagePickerHelperWithMetadata(presentingViewController: topVC, sourceType: sourceType, continuation: continuation)
            // Retain the helper by associating it with the presenting view controller until dismissal.
            objc_setAssociatedObject(topVC, Unmanaged.passUnretained(helper).toOpaque(), helper, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            helper.present()
        }
    }
}
