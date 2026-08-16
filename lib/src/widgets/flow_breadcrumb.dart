import 'package:flutter/material.dart';

/// Logical breadcrumb trail for the game flow (not tied to route history).
///
/// When [showHome] is true, a home icon is shown first (not the word "Home").
class FlowBreadcrumb extends StatelessWidget {
  final List<String> segments;
  /// Show a leading home icon before [segments].
  final bool showHome;
  /// Tap on the home icon.
  final VoidCallback? onHomeTap;
  /// Called for a non-last text segment tap (index into [segments]).
  final ValueChanged<int>? onSegmentTap;
  /// Legacy: tap on the first text segment when there is more than one.
  final VoidCallback? onFirstSegmentTap;

  const FlowBreadcrumb({
    super.key,
    required this.segments,
    this.showHome = false,
    this.onHomeTap,
    this.onSegmentTap,
    this.onFirstSegmentTap,
  });

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty && !showHome) return const SizedBox.shrink();

    final style = DefaultTextStyle.of(context).style.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        );
    final muted = style.copyWith(color: style.color?.withValues(alpha: 0.7));
    final iconColor = muted.color ?? style.color;

    final children = <Widget>[];

    if (showHome) {
      final homeIcon = Icon(Icons.home, size: 20, color: iconColor);
      children.add(
        onHomeTap != null
            ? InkWell(
                onTap: onHomeTap,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: homeIcon,
                ),
              )
            : homeIcon,
      );
      if (segments.isNotEmpty) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('>', style: muted),
        ));
      }
    }

    for (var i = 0; i < segments.length; i++) {
      if (i > 0) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('>', style: muted),
        ));
      }
      final isLast = i == segments.length - 1;
      final text = Text(
        segments[i],
        style: isLast ? style : muted,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      );

      VoidCallback? onTap;
      if (!isLast) {
        if (onSegmentTap != null) {
          onTap = () => onSegmentTap!(i);
        } else if (i == 0 && onFirstSegmentTap != null) {
          onTap = onFirstSegmentTap;
        }
      }

      Widget segment = text;
      if (onTap != null) {
        segment = InkWell(onTap: onTap, child: text);
      }
      children.add(Flexible(child: segment));
    }

    return Row(children: children);
  }
}
