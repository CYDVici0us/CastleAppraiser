import 'package:flutter/material.dart';

class EditTextDialog extends StatefulWidget {

  final String confirmationText;
  final void Function(String) onPressedYes;
  final void Function()? onPressedNo;
  final bool popOnYes;
  final String defaultText;

  EditTextDialog({
    required this.confirmationText,
    required this.onPressedYes,
    this.defaultText='',
    this.onPressedNo,
    this.popOnYes=true,
  });

  @override
  State createState() => _EditTextDialogState();
}

class _EditTextDialogState extends State<EditTextDialog> {

  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.defaultText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  onPressedYes(BuildContext context) {
    widget.onPressedYes(_controller.text);

    if (widget.popOnYes) {
      Navigator.pop(context);
    }
  }

  List<Widget> _getActions(BuildContext context) => <Widget>[
    TextButton(
      child: Text('Cancel'),
      onPressed: () {
        widget.onPressedNo?.call();
        Navigator.pop(context);
      },
    ),
    TextButton(
      child: Text('Save'),
      onPressed: () async => await onPressedYes(context),
    ),
  ];

  Widget _getContent(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(widget.confirmationText),
      TextField(
        controller: _controller,
        autofocus: true,
        textAlign: TextAlign.center,
        showCursor: true,
      )
    ],
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    content: _getContent(context),
    actions: _getActions(context),
  );
}
