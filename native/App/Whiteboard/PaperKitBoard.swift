//  Story 1217 (bead context-grabber-0xrz): the PaperKit board, a scratch page with every pen and shape PaperKit has, so
//  Igor can feel them before the real board takes any. The real board (`PaperHost`) turns on drawing alone; this turns on
//  everything, with the fountain pen in hand. Nothing here is saved or sent: closing it throws the page away.

import ContextCore
import PaperKit
import PencilKit
import SwiftUI
import UIKit

/// The scratch page, from Settings' *About and diagnostics* on the iPad.
struct PaperKitBoardView: View {
  let log: SessionLog

  var body: some View {
    PaperKitBoardPage(log: log)
      .ignoresSafeArea(edges: .bottom)
      .navigationTitle("PaperKit board")
      .navigationBarTitleDisplayMode(.inline)
      .accessibilityIdentifier("paperkit-board")
  }
}

private struct PaperKitBoardPage: UIViewControllerRepresentable {
  let log: SessionLog

  func makeUIViewController(context: Context) -> PaperKitBoardController { PaperKitBoardController(log: log) }
  func updateUIViewController(_ controller: PaperKitBoardController, context: Context) {}
}

/// PaperKit's controller with every feature, shape, line end and ink on, and PaperKit's own insert menu behind the tool
/// picker's **+**.
@MainActor
final class PaperKitBoardController: UIViewController {
  /// Every pen this SDK has (PencilKit's `PKInkType.h`), the fountain pen first: the one in hand when the page opens.
  static let inks: [PKInkingTool.InkType] = [
    .fountainPen, .pen, .pencil, .marker, .monoline, .watercolor, .crayon, .reed,
  ]

  /// Everything PaperKit offers on this SDK.
  static let features: FeatureSet = {
    var set = FeatureSet.latest
    set.contentVersion = .latest
    for feature in FeatureSet.Feature.allCases { set.insert(feature) }
    set.shapes = Set(ShapeConfiguration.Shape.allCases)
    set.lineMarkerPositions = .all
    set.inks = Set(inks)
    return set
  }()

  /// Igor, 2026-11-22 (via Larry): the fountain pen is a bit thick. The one in hand is 60% of PencilKit's default width
  /// (kept inside the ink's valid widths), with the nib held at 45° (π/4 radians; `azimuth` is iOS 26+).
  static let fountainWidthShare: CGFloat = 0.6
  static let fountainAzimuth: CGFloat = .pi / 4
  static var fountainWidth: CGFloat {
    let ink = PKInkingTool.InkType.fountainPen
    let range = ink.validWidthRange
    return min(max(ink.defaultWidth * fountainWidthShare, range.lowerBound), range.upperBound)
  }

  private let log: SessionLog
  private let paper: PaperMarkupViewController
  /// Held here: the tool picker disappears when nothing keeps it.
  private let picker: PKToolPicker

  init(log: SessionLog) {
    self.log = log
    paper = PaperMarkupViewController(markup: PaperMarkup(bounds: .zero), supportedFeatureSet: Self.features)
    var items: [PKToolPickerItem] = Self.inks.map { ink in
      ink == .fountainPen
        ? PKToolPickerInkingItem(type: ink, width: Self.fountainWidth, azimuth: Self.fountainAzimuth)
        : PKToolPickerInkingItem(type: ink)
    }
    items.append(PKToolPickerEraserItem(type: .vector))
    items.append(PKToolPickerLassoItem())
    items.append(PKToolPickerRulerItem())
    picker = PKToolPicker(toolItems: items)
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) { nil }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    addChild(paper)
    paper.view.frame = view.bounds
    paper.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(paper.view)
    paper.didMove(toParent: self)
    paper.markup = PaperMarkup(bounds: view.bounds)
    picker.accessoryItem = UIBarButtonItem(
      image: UIImage(systemName: "plus"), primaryAction: UIAction { [weak self] _ in self?.showInsertMenu() })
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if paper.markup?.bounds.isEmpty ?? true { paper.markup = PaperMarkup(bounds: view.bounds) }
    picker.addObserver(paper)
    if let fountain = picker.toolItems.first(where: {
      ($0 as? PKToolPickerInkingItem)?.inkingTool.inkType == .fountainPen
    }) {
      picker.selectedToolItem = fountain
    }
    paper.drawingTool = PKInkingTool(
      .fountainPen, color: .label, width: Self.fountainWidth, azimuth: Self.fountainAzimuth)
    paper.pencilKitResponderState.activeToolPicker = picker
    paper.pencilKitResponderState.toolPickerVisibility = .visible
    let tool = paper.drawingTool as? PKInkingTool
    log.event(
      "paperkit_board",
      [
        "action": "opened", "inks": Self.inks.map(\.rawValue),
        "shapes": Self.features.shapes.count, "features": Self.features.features.count,
        "tool": tool?.inkType.rawValue ?? "other", "width": Double(tool?.width ?? 0),
        "default_width": Double(PKInkingTool.InkType.fountainPen.defaultWidth),
        "azimuth": Double(Self.fountainAzimuth),
      ])
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    paper.pencilKitResponderState.toolPickerVisibility = .hidden
    picker.removeObserver(paper)
    log.event(
      "paperkit_board", ["action": "closed", "elements": paper.markup?.subelements.count ?? 0])
  }

  /// PaperKit's own menu of shapes, text boxes, lines and arrows, stickers and images; the paper inserts what's picked.
  private func showInsertMenu() {
    let menu = MarkupEditViewController(supportedFeatureSet: Self.features)
    menu.delegate = paper
    menu.modalPresentationStyle = .popover
    menu.popoverPresentationController?.sourceItem = picker.accessoryItem
    present(menu, animated: true)
  }
}
