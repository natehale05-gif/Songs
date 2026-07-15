import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Small, shared building blocks that give the whole app a consistent,
/// Apple-quality feel: gentle press feedback, tactile haptics, iOS-style page
/// transitions (with swipe-to-go-back), and bouncy scrolling.

/// Lightweight haptic helpers. These are no-ops on platforms without a Taptic
/// Engine (e.g. web), so they are always safe to call.
class Haptics {
  const Haptics._();

  static void light() => HapticFeedback.lightImpact();
  static void selection() => HapticFeedback.selectionClick();
  static void medium() => HapticFeedback.mediumImpact();
}

/// A tap target that dims and scales down slightly while pressed — the same
/// subtle "give" Apple uses on buttons, cards and controls. Fires a light
/// haptic on release before invoking [onTap].
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.96,
    this.haptic = true,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;
  final HitTestBehavior behavior;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) Haptics.light();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              if (widget.haptic) Haptics.medium();
              widget.onLongPress!();
            },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _down ? 0.7 : 1.0,
          duration: const Duration(milliseconds: 110),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Pushes a route using an iOS-style horizontal slide that also supports the
/// interactive swipe-from-left-edge back gesture.
Route<T> appPage<T>(WidgetBuilder builder) =>
    CupertinoPageRoute<T>(builder: builder);

/// Scroll behavior with iOS rubber-band overscroll and no Android glow.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}

/// A translucent, blurred bar — the frosted "glass" material Apple uses for
/// navigation bars and toolbars. Whatever scrolls behind it shows through,
/// softly blurred, exactly like iOS.
class FrostedBar extends StatelessWidget {
  const FrostedBar({
    super.key,
    required this.child,
    required this.color,
    this.border,
    this.sigma = 22,
  });

  final Widget child;
  final Color color;
  final Border? border;
  final double sigma;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, border: border),
          child: child,
        ),
      ),
    );
  }
}

/// A fixed-height sliver that stays pinned to the top of a [CustomScrollView],
/// used to keep a frosted toolbar in place while content scrolls beneath it.
class PinnedBarDelegate extends SliverPersistentHeaderDelegate {
  const PinnedBarDelegate({required this.extent, required this.child});

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      SizedBox.expand(child: child);

  @override
  bool shouldRebuild(covariant PinnedBarDelegate oldDelegate) =>
      oldDelegate.child != child || oldDelegate.extent != extent;
}

/// iOS-style page transitions applied across every platform for consistency.
const PageTransitionsTheme kAppPageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: CupertinoPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
    TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
    TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
  },
);
