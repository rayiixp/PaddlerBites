import 'package:flutter/material.dart';
import 'delivery_tracking_map.dart';

/// Shared layout of the live tracking screens (customer and rider): a
/// full-screen map with a low-profile white card at the bottom that can be
/// dragged up for details.
///
/// The map is built with the padding covered by the collapsed card so it can
/// centre its content in the part that stays visible.
class TrackingScaffold extends StatelessWidget {
  /// Builds the map; [overlayPadding] is the area hidden behind the card.
  final Widget Function(BuildContext context, EdgeInsets overlayPadding) mapBuilder;

  /// Builds the card contents inside a scroll view driven by the sheet.
  final List<Widget> Function(BuildContext context) cardChildren;

  /// Height of the collapsed card (content that must always be visible).
  final double collapsedHeight;

  /// Shows a back button in the top-left corner. Leave null when the map
  /// draws its own top bar (DeliveryTrackingMap.onBack).
  final VoidCallback? onBack;

  const TrackingScaffold({
    super.key,
    required this.mapBuilder,
    required this.cardChildren,
    this.collapsedHeight = 236,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screen = media.size.height;
    final minSize = ((collapsedHeight + media.padding.bottom) / screen).clamp(0.2, 0.5);
    final initialSize = (minSize + 0.06).clamp(minSize, 0.55);

    return Scaffold(
      body: Stack(
        children: [
          mapBuilder(context, EdgeInsets.only(bottom: screen * initialSize)),
          if (onBack != null)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: MapCircleButton(icon: Icons.arrow_back, tooltip: 'Back', onPressed: onBack!),
              ),
            ),
          DraggableScrollableSheet(
            initialChildSize: initialSize,
            minChildSize: minSize,
            maxChildSize: 0.8,
            snap: true,
            snapSizes: [initialSize],
            builder: (context, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4))],
              ),
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + media.padding.bottom),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...cardChildren(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
