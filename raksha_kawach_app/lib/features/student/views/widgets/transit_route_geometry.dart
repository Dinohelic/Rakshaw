import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// TransitRouteGeometry — Google Stitch transit corridor visualization.
/// Renders origin node, bus transit node, and destination terminal with
/// connecting dashed lines.
///
/// Requirement: Decorative unless actual route stops are available.
/// Do NOT label fictional stops as genuine student assignments.
class TransitRouteGeometry extends StatelessWidget {
  final String origin;
  final String transportIdentifier;
  final String destination;
  final bool isIllustrative;
  final Color? backgroundColor;

  const TransitRouteGeometry({
    super.key,
    this.origin = 'Campus Origin',
    this.transportIdentifier = 'Transit Bus',
    this.destination = 'Terminal Gate',
    this.isIllustrative = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isIllustrative
          ? 'Illustrative transit route path from $origin to $destination'
          : 'Transit route from $origin via $transportIdentifier to $destination',
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // Node 1: Origin
                Flexible(
                  flex: 3,
                  child: _buildNode(
                    dotColor: AppColors.primaryContainer,
                    label: origin,
                    isOrigin: true,
                  ),
                ),

                // Dashed Line with Bus Icon
                Expanded(
                  flex: 2,
                  child: _buildDashedConnector(
                    centerWidget: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      color: backgroundColor ?? AppColors.surfaceContainerLowest,
                      child: const Icon(
                        Icons.directions_bus,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),

                // Node 2: Vehicle
                Flexible(
                  flex: 3,
                  child: _buildNode(
                    dotColor: AppColors.primary,
                    label: transportIdentifier,
                    isCenter: true,
                  ),
                ),

                // Dashed Line with Arrow
                Expanded(
                  flex: 2,
                  child: _buildDashedConnector(
                    centerWidget: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      color: backgroundColor ?? AppColors.surfaceContainerLowest,
                      child: const Icon(
                        Icons.arrow_forward,
                        size: 14,
                        color: AppColors.outline,
                      ),
                    ),
                  ),
                ),

                // Node 3: Destination
                Flexible(
                  flex: 3,
                  child: _buildNode(
                    dotColor: AppColors.outline,
                    label: destination,
                    isDestination: true,
                  ),
                ),
              ],
            ),
            if (isIllustrative) ...[
              const SizedBox(height: 8),
              const Text(
                'Route geometry visualization • Stops subject to university scheduling',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9.5,
                  color: AppColors.outline,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNode({
    required Color dotColor,
    required String label,
    bool isOrigin = false,
    bool isCenter = false,
    bool isDestination = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.labelSm.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildDashedConnector({required Widget centerWidget}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(constraints.maxWidth, 2),
              painter: _DashedLinePainter(color: AppColors.outlineVariant),
            ),
            centerWidget,
          ],
        );
      },
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;

  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 3.5;
    const dashSpace = 3.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
