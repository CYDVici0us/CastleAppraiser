import 'package:btcc/src/utils/typedefs.dart';
import 'package:flutter/material.dart';

class FilteredDragAndDropListView<T extends Object> extends StatefulWidget {
  final String hintText;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onClearPressed;
  final DragTargetAcceptWithScrollControllerCallback<T> onAcceptWithDetails;
  final List<Widget> children;
  final Axis scrollDirection;
  final EdgeInsetsGeometry listItemPadding;
  final double listHeight;
  /// Outer strip behind results; null = transparent (panel shows through).
  final Color? containerColor;
  /// Fill behind the search field; null = theme surface container.
  final Color? textBackgroundColor;

  FilteredDragAndDropListView({
    super.key,
    required this.hintText,
    required this.onTextChanged,
    required this.onClearPressed,
    required this.onAcceptWithDetails,
    required this.children,
    this.scrollDirection = Axis.horizontal,
    this.listItemPadding =
        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    this.listHeight = 100,
    this.containerColor,
    this.textBackgroundColor,
  });

  @override
  createState() => _FilteredDragAndDropListViewState<T>();
}

class _FilteredDragAndDropListViewState<T extends Object>
    extends State<FilteredDragAndDropListView<T>> {
  late TextEditingController _textEditingController;
  late ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _textEditingController = TextEditingController();
    _controller = ScrollController();
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _textEditingController.clear();
    widget.onClearPressed();
    FocusScope.of(context).unfocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasResults = widget.children.isNotEmpty;
    final hasText = _textEditingController.text.isNotEmpty;

    final fieldFill = widget.textBackgroundColor ??
        cs.surfaceContainerHigh.withValues(alpha: 0.55);
    final onField = cs.onSurface;
    final onFieldMuted = cs.onSurfaceVariant;

    return ColoredBox(
      color: widget.containerColor ?? Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasResults)
            SizedBox(
              height: widget.listHeight,
              child: DragTarget<T>(
                onAcceptWithDetails: (details) =>
                    widget.onAcceptWithDetails(details, _controller),
                builder: (_, __, ___) => ListView(
                  controller: _controller,
                  scrollDirection: widget.scrollDirection,
                  padding: widget.listItemPadding,
                  children: widget.children,
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(10, hasResults ? 2 : 0, 10, 10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fieldFill,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: cs.outline.withValues(alpha: 0.85),
                  width: 1.25,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 4, 2),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      size: 20,
                      color: onFieldMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _textEditingController,
                        textAlign: TextAlign.start,
                        showCursor: true,
                        autofocus: false,
                        onChanged: (value) {
                          setState(() {});
                          widget.onTextChanged(value);
                        },
                        cursorColor: cs.primary,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: onField,
                        ),
                        decoration: InputDecoration(
                          hintText: widget.hintText,
                          hintStyle: theme.textTheme.bodyLarge?.copyWith(
                            color: onFieldMuted,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: hasText ? _clear : null,
                      style: TextButton.styleFrom(
                        foregroundColor: cs.primary,
                        disabledForegroundColor:
                            onFieldMuted.withValues(alpha: 0.45),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
