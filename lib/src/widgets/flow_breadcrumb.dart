import 'package:flutter/material.dart';

/// Logical breadcrumb trail for the game flow (not tied to route history).
class FlowBreadcrumb extends StatelessWidget {
  final List<String> segments;
  final VoidCallback? onFirstSegmentTap;

  const FlowBreadcrumb({
    super.key,
    required this.segments,
    this.onFirstSegmentTap,
  });

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) return const SizedBox.shrink();

    final style = DefaultTextStyle.of(context).style.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    final muted = style.copyWith(color: style.color?.withValues(alpha: 0.7));

    final children = <Widget>[];
    for (var i = 0; i < segments.length; i++) {
      if (i > 0) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('>', style: muted),
        ));
      }
      final isFirst = i == 0;
      final isLast = i == segments.length - 1;
      final text = Text(
        segments[i],
        style: isLast ? style : muted,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      );
      Widget segment = text;
      if (isFirst && onFirstSegmentTap != null && segments.length > 1) {
        segment = InkWell(onTap: onFirstSegmentTap, child: text);
      }
      children.add(Flexible(child: segment));
    }

    return Row(children: children);
  }
}
