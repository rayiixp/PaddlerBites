import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/models.dart';
import 'premium_paddling_boat.dart';

/// Placed → Preparing → Picked up → On the way → Delivered.
///
/// A static track (step icons, labels and connectors) with the animated
/// paddling boat (the PaddlerBites mascot) on top of the current step.
/// Finished steps show a yellow check and upcoming steps a grey icon for
/// their stage. When the status changes, the boat glides along the track to
/// the new step while the connector behind it fills in yellow.
class OrderStatusTimeline extends StatelessWidget {
  final String status;
  const OrderStatusTimeline({super.key, required this.status});

  static const steps = ['Placed', 'Preparing', 'Picked up', 'On the way', 'Delivered'];

  /// Icon shown for each step until it's reached.
  static const icons = [
    Icons.receipt_long_outlined,
    Icons.soup_kitchen_outlined,
    Icons.shopping_bag_outlined,
    Icons.directions_run_outlined,
    Icons.home_outlined,
  ];

  /// How long the boat takes to paddle over to the next step.
  static const glideDuration = Duration(milliseconds: 700);
  static const glideCurve = Curves.easeInOut;

  static const double _stepWidth = 56;
  static const double _boatSize = 44;

  /// Timeline position of an order status. 'Ready' is still the Preparing
  /// step: the food waits at the stall for a rider.
  static int stepIndex(String status) => switch (status) {
        OrderStatus.pending => 0,
        OrderStatus.preparing || OrderStatus.ready => 1,
        OrderStatus.pickedUp => 2,
        OrderStatus.onTheWay => 3,
        OrderStatus.delivered => 4,
        _ => -1, // cancelled / unknown
      };

  @override
  Widget build(BuildContext context) {
    final current = stepIndex(status);
    final delivered = status == OrderStatus.delivered;

    return LayoutBuilder(
      builder: (context, constraints) {
        // The connectors share whatever width the fixed-width steps leave.
        final gap = (constraints.maxWidth - _stepWidth * steps.length) / (steps.length - 1);
        double boatLeft(int step) => step * (_stepWidth + gap) + (_stepWidth - _boatSize) / 2;

        return Stack(
          children: [
            // Static track.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  if (i > 0) Expanded(child: _Connector(done: i <= current)),
                  _StepNode(
                    label: steps[i],
                    icon: icons[i],
                    state: i < current
                        ? _StepState.done
                        : i == current
                            ? _StepState.current
                            : _StepState.upcoming,
                  ),
                ],
              ],
            ),
            // The boat paddles over the current step's slot.
            if (current >= 0)
              AnimatedPositioned(
                duration: glideDuration,
                curve: glideCurve,
                left: boatLeft(current),
                top: 0,
                width: _boatSize,
                height: _boatSize,
                // The boat keeps paddling until the order has arrived.
                child: PremiumPaddlingBoatAnimation(size: _boatSize, animate: !delivered),
              ),
          ],
        );
      },
    );
  }
}

enum _StepState { done, current, upcoming }

class _StepNode extends StatelessWidget {
  final String label;
  final IconData icon;
  final _StepState state;
  const _StepNode({required this.label, required this.icon, required this.state});

  static const double _nodeSize = 26;

  @override
  Widget build(BuildContext context) {
    final isCurrent = state == _StepState.current;
    return SizedBox(
      width: OrderStatusTimeline._stepWidth,
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: switch (state) {
                  // Left empty: the gliding boat sits here.
                  _StepState.current => const SizedBox(key: ValueKey('current'), width: _nodeSize, height: _nodeSize),
                  _StepState.done => Container(
                      key: const ValueKey('done'),
                      width: _nodeSize,
                      height: _nodeSize,
                      decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
                      child: const Icon(Icons.check, size: 16, color: Colors.black),
                    ),
                  _StepState.upcoming => Icon(
                      icon,
                      key: const ValueKey('upcoming'),
                      size: 24,
                      color: Colors.grey.shade400,
                    ),
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.2,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
              color: state == _StepState.upcoming ? Colors.grey : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

/// Grey line between two steps; fills with yellow from the left, in step
/// with the boat, once the step it leads to is reached.
class _Connector extends StatelessWidget {
  final bool done;
  const _Connector({required this.done});

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Vertically centred on the 44 px node row, with a little breathing
      // room around the icons.
      padding: const EdgeInsets.only(top: 21, left: 2, right: 2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Container(
          height: 3,
          color: Colors.grey.shade300,
          alignment: Alignment.centerLeft,
          child: AnimatedFractionallySizedBox(
            duration: OrderStatusTimeline.glideDuration,
            curve: OrderStatusTimeline.glideCurve,
            widthFactor: done ? 1 : 0,
            heightFactor: 1,
            child: const ColoredBox(color: AppTheme.primaryColor),
          ),
        ),
      ),
    );
  }
}
