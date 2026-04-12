import XCTest
import SwiftUI
import UIKit
@testable import Jouzu

@MainActor
final class ScreenshotTests: XCTestCase {
    private let screenshotSize = CGSize(width: 393, height: 852)

    func testRenderHomeScreenshot() throws {
        try renderScreenshot(
            named: "home",
            view: ScreenshotRootView(destination: .home)
        )
    }

    func testRenderAnalysisScreenshot() throws {
        try renderScreenshot(
            named: "analysis",
            view: ScreenshotRootView(destination: .analysis)
        )
    }

    func testRenderAnalysisDetailScreenshot() throws {
        try renderScreenshot(
            named: "analysis_detail",
            view: ScreenshotRootView(destination: .analysisDetail)
        )
    }

    func testRenderVocabularyScreenshot() throws {
        try renderScreenshot(
            named: "vocabulary",
            view: ScreenshotRootView(destination: .vocabulary)
        )
    }

    func testRenderReviewScreenshot() throws {
        try renderScreenshot(
            named: "review",
            view: ScreenshotRootView(destination: .review)
        )
    }

    private func renderScreenshot<Content: View>(named name: String, view: Content) throws {
        let content = view
            .modelContainer(PreviewSampleData.previewModelContainer)
            .environment(SyncCoordinator.preview)
            .frame(width: screenshotSize.width, height: screenshotSize.height)
            .background(Color(.systemBackground))
            .environment(\.dynamicTypeSize, .medium)
            .preferredColorScheme(.light)

        let image = try snapshotImage(for: content)
        guard let pngData = image.pngData() else {
            XCTFail("Failed to encode \(name).png")
            return
        }

        let outputURL = screenshotsDirectoryURL.appendingPathComponent("\(name).png")
        try FileManager.default.createDirectory(
            at: screenshotsDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        try pngData.write(to: outputURL, options: .atomic)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }

    private func snapshotImage<Content: View>(for view: Content) throws -> UIImage {
        let windowScene = try XCTUnwrap(
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first
        )

        let hostingController = UIHostingController(rootView: view)
        let window = UIWindow(windowScene: windowScene)
        window.frame = CGRect(origin: .zero, size: screenshotSize)
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = hostingController
        window.makeKeyAndVisible()

        hostingController.view.frame = window.bounds
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))

        let renderer = UIGraphicsImageRenderer(size: screenshotSize)
        let image = renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }

        window.isHidden = true
        return image
    }

    private var screenshotsDirectoryURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Screenshots", isDirectory: true)
    }
}
