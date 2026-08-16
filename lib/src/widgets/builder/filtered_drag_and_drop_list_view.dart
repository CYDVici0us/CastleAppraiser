import 'package:btcc/src/app/app_widget.dart';
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
  final Color containerColor;
  final Color textBackgroundColor;

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
    this.containerColor = AppColors.card,
    this.textBackgroundColor = AppColors.cardElevated,
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
    final hasResults = widget.children.isNotEmpty;
    final hasText = _textEditingController.text.isNotEmpty;

    return Container(
      color: widget.containerColor,
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
          Container(
            color: widget.textBackgroundColor,
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textEditingController,
                    textAlign: TextAlign.center,
                    showCursor: true,
                    autofocus: false,
                    onChanged: (value) {
                      setState(() {});
                      widget.onTextChanged(value);
                    },
                    cursorColor: Colors.white,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: const TextStyle(color: Colors.white70),
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: hasText ? _clear : null,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white38,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
