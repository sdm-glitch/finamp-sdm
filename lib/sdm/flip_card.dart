// SDM build (patch 0002-flipcard-lyrics): a card that turns over around its vertical axis.
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Shows [front] or [back]; [flipped] turns it over with a 3D flip animation.
/// Only the visible side is built.
class SdmFlipCard extends StatefulWidget {
  const SdmFlipCard({
    super.key,
    required this.flipped,
    required this.front,
    required this.back,
    this.duration = const Duration(milliseconds: 450),
  });

  final ValueListenable<bool> flipped;
  final Widget front;
  final Widget back;
  final Duration duration;

  @override
  State<SdmFlipCard> createState() => _SdmFlipCardState();
}

class _SdmFlipCardState extends State<SdmFlipCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.flipped.value ? 1.0 : 0.0,
  );

  @override
  void initState() {
    super.initState();
    widget.flipped.addListener(_onFlippedChanged);
  }

  @override
  void didUpdateWidget(covariant SdmFlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flipped != widget.flipped) {
      oldWidget.flipped.removeListener(_onFlippedChanged);
      widget.flipped.addListener(_onFlippedChanged);
      _onFlippedChanged();
    }
  }

  void _onFlippedChanged() {
    if (!mounted) return;
    final target = widget.flipped.value ? 1.0 : 0.0;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller.value = target;
    } else {
      _controller.animateTo(target, curve: Curves.easeInOut);
    }
  }

  @override
  void dispose() {
    widget.flipped.removeListener(_onFlippedChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final angle = _controller.value * pi;
        final showBack = angle > pi / 2;
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateY(showBack ? angle - pi : angle);
        return Transform(
          alignment: Alignment.center,
          transform: transform,
          child: showBack
              ? KeyedSubtree(key: const ValueKey("sdm-card-back"), child: widget.back)
              : KeyedSubtree(key: const ValueKey("sdm-card-front"), child: widget.front),
        );
      },
    );
  }
}
