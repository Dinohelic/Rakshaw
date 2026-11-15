import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// RakshaBrandEmblem — Google Stitch signature brand emblem.
/// Renders a dark charcoal rounded container with an inner shield/bus emblem,
/// and an optional live pulsing emerald beacon dot.
class RakshaBrandEmblem extends StatefulWidget {
  /// When false (e.g. in test environments or accessibility reduced motion),
  /// the pulse animation does not repeat indefinitely so [pumpAndSettle] can settle.
  static bool enablePulseAnimation = true;

  final double size;
  final bool showLivePing;
  final Color backgroundColor;
  final Color iconColor;
  final Color pingColor;
  final String semanticsLabel;
  final bool useAssetLogo;

  const RakshaBrandEmblem({
    super.key,
    this.size = 48.0,
    this.showLivePing = false,
    this.backgroundColor = AppColors.onSurface,
    this.iconColor = AppColors.primaryContainer,
    this.pingColor = AppColors.primary,
    this.semanticsLabel = 'Raksha Kawach Live System Shield',
    this.useAssetLogo = true,
  });

  @override
  State<RakshaBrandEmblem> createState() => _RakshaBrandEmblemState();
}

class _RakshaBrandEmblemState extends State<RakshaBrandEmblem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 2.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.8, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (widget.showLivePing &&
        RakshaBrandEmblem.enablePulseAnimation &&
        !isTest) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(RakshaBrandEmblem oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (widget.showLivePing &&
        RakshaBrandEmblem.enablePulseAnimation &&
        !isTest &&
        !_pulseController.isAnimating) {
      _pulseController.repeat();
    } else if (!widget.showLivePing && _pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(widget.size * 0.3);
    final iconSize = widget.size * 0.52;
    final pingDotSize = widget.size * 0.22;

    return Semantics(
      label: widget.semanticsLabel,
      image: true,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Emblem Base Container
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: borderRadius,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14171717),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: widget.useAssetLogo
                  ? Padding(
                      padding: EdgeInsets.all(widget.size * 0.12),
                      child: Image.asset(
                        'assets/Logo.png',
                        width: widget.size * 0.76,
                        height: widget.size * 0.76,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.shield_outlined,
                          size: iconSize,
                          color: widget.iconColor,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.shield_outlined,
                      size: iconSize,
                      color: widget.iconColor,
                    ),
            ),
          ),

          // Live Pulse Dot (Top Right)
          if (widget.showLivePing)
            Positioned(
              top: -pingDotSize * 0.15,
              right: -pingDotSize * 0.15,
              child: SizedBox(
                width: pingDotSize * 2.2,
                height: pingDotSize * 2.2,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Container(
                            width: pingDotSize,
                            height: pingDotSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryContainer
                                  .withValues(alpha: _fadeAnimation.value),
                            ),
                          ),
                        );
                      },
                    ),
                    Container(
                      width: pingDotSize,
                      height: pingDotSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.pingColor,
                        border: Border.all(
                          color: AppColors.surface,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

