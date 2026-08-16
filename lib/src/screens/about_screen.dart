import 'dart:io';

import 'package:btcc/src/screens/legal_document_screen.dart';
import 'package:btcc/src/screens/logs_screen.dart';
import 'package:btcc/src/state/data_store.dart';
import 'package:btcc/src/utils/log.dart';
import 'package:btcc/src/utils/navigation_helper.dart';
import 'package:btcc/src/widgets/background_container.dart';
import 'package:btcc/src/widgets/flow_breadcrumb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launchEmail(String dir) async {
    var hasLogsFile = false;
    final filePath = '$dir/logs.txt';
    try {
      final tempLog = File(filePath);
      await tempLog.writeAsString(logs.join('\n'));
      hasLogsFile = true;
    } catch (ex) {
      log('Failed to save logs to file for email: $ex');
      hasLogsFile = false;
    }

    final email = Email(
      subject: 'Castle Appraiser 2.0 Feedback',
      recipients: ['castleappraiser2@cydvicious.com'],
      attachmentPaths: hasLogsFile ? [filePath] : [],
    );
    await FlutterEmailSender.send(email);
  }

  void _openLogs(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LogsScreen(
          emailLogs: () {
            final store = Provider.of<DataStore>(context, listen: false);
            _launchEmail(store.imagesTempPath);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
      height: 1.35,
    );

    Widget sectionLabel(String text) => Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 6),
          child: Text(
            text,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        );

    Widget linkTile({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label, style: theme.textTheme.bodyMedium),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: FlowBreadcrumb(
          showHome: true,
          onHomeTap: () => NavigationHelper.popToHome(context),
          segments: const ['About'],
        ),
      ),
      body: BackgroundContainer(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'Castle Appraiser 2.0',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            sectionLabel('About'),
            Text(
              'Unofficial companion app for Between Two Castles of '
              'Mad King Ludwig. Not affiliated with Stonemaier Games.',
              style: muted,
            ),
            const SizedBox(height: 18),
            sectionLabel('From Author'),
            Text(
              'Thank you for using this app. Updating it has been a '
              'pleasure, especially working to make it more '
              'user-friendly and accessible. I hope it makes scoring '
              'a little smoother and helps you to keep enjoying '
              'Stonemaier\'s excellent game.',
              style: muted,
            ),
            const SizedBox(height: 14),
            Text(
              'Not currently available on iOS. A MacBook donation '
              'would make a port possible. 😉',
              style: muted,
            ),
            const SizedBox(height: 8),
            linkTile(
              icon: Icons.person_outline,
              label: '~CYD',
              onTap: () => launchUrl(
                Uri.parse('https://github.com/CYDVici0us'),
              ),
            ),
            const SizedBox(height: 18),
            sectionLabel('Credits'),
            Text(
              'Huge thanks to Mitch Hymel for the original '
              'Castle Appraiser.',
              style: muted,
            ),
            linkTile(
              icon: Icons.code,
              label: 'github.com/mitchhymel/CastleAppraiser',
              onTap: () => launchUrl(
                Uri.parse('https://github.com/mitchhymel/CastleAppraiser'),
              ),
            ),
            const SizedBox(height: 4),
            sectionLabel('Feedback & legal'),
            linkTile(
              icon: Icons.email_outlined,
              label: 'Send feedback',
              onTap: () {
                final store = Provider.of<DataStore>(context, listen: false);
                _launchEmail(store.imagesTempPath);
              },
            ),
            linkTile(
              icon: Icons.article_outlined,
              label: 'View logs',
              onTap: () => _openLogs(context),
            ),
            linkTile(
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy policy',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const LegalDocumentScreen(
                    kind: LegalDocumentKind.privacy,
                  ),
                ),
              ),
            ),
            linkTile(
              icon: Icons.gavel_outlined,
              label: 'Terms of use',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const LegalDocumentScreen(
                    kind: LegalDocumentKind.terms,
                  ),
                ),
              ),
            ),
            linkTile(
              icon: Icons.description_outlined,
              label: 'Open source licenses',
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'Castle Appraiser 2.0',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
