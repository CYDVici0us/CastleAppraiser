import 'package:btcc/src/utils/log.dart';
import 'package:btcc/src/utils/navigation_helper.dart';
import 'package:btcc/src/widgets/background_container.dart';
import 'package:btcc/src/widgets/flow_breadcrumb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class LogsScreen extends HookWidget {
  final VoidCallback emailLogs;
  final List<String> breadcrumbSegments;

  LogsScreen({
    required this.emailLogs,
    this.breadcrumbSegments = const ['About', 'Logs'],
  });

  @override
  Widget build(BuildContext context) {
    final controller = useScrollController();
    return Scaffold(
      appBar: AppBar(
        title: FlowBreadcrumb(
          showHome: true,
          onHomeTap: () => NavigationHelper.popToHome(context),
          segments: breadcrumbSegments,
          onSegmentTap: (index) {
            if (index == 0) {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mail),
            tooltip: 'Email logs',
            onPressed: emailLogs,
          ),
        ],
      ),
      body: BackgroundContainer(
        child: Scrollbar(
          controller: controller,
          child: ListView.builder(
            controller: controller,
            itemCount: logs.length,
            itemBuilder: (context, index) => Text(logs[index]),
          ),
        ),
      ),
    );
  }
}
