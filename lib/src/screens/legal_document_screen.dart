import 'package:btcc/src/utils/navigation_helper.dart';
import 'package:btcc/src/widgets/background_container.dart';
import 'package:btcc/src/widgets/flow_breadcrumb.dart';
import 'package:flutter/material.dart';

enum LegalDocumentKind { privacy, terms }

class LegalDocumentScreen extends StatelessWidget {
  final LegalDocumentKind kind;

  const LegalDocumentScreen({super.key, required this.kind});

  String get _title => switch (kind) {
        LegalDocumentKind.privacy => 'Privacy Policy',
        LegalDocumentKind.terms => 'Terms of Use',
      };

  List<String> get _segments => ['About', _title];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
      height: 1.4,
    );
    final headingStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.primary,
    );

    final sections = kind == LegalDocumentKind.privacy
        ? _privacySections()
        : _termsSections();

    return Scaffold(
      appBar: AppBar(
        title: FlowBreadcrumb(
          showHome: true,
          onHomeTap: () => NavigationHelper.popToHome(context),
          segments: _segments,
          onSegmentTap: (index) {
            if (index == 0) Navigator.of(context).pop();
          },
        ),
      ),
      body: BackgroundContainer(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              _title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Last updated: August 16, 2026',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 16),
            for (final section in sections) ...[
              Text(section.title, style: headingStyle),
              const SizedBox(height: 6),
              Text(section.body, style: bodyStyle),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  List<_LegalSection> _privacySections() => const [
        _LegalSection(
          'Overview',
          'Castle Appraiser 2.0 ("the App") is an unofficial companion for '
              'Between Two Castles of Mad King Ludwig. This policy describes '
              'what information the App handles and how it is used. The App is '
              'not affiliated with Stonemaier Games.',
        ),
        _LegalSection(
          'Information stored on your device',
          'Games, castles, scores, and related edits you create are stored '
              'locally on your device (including via on-device databases such as '
              'Hive). Photos you capture or import for scoring may also be kept '
              'temporarily or saved to your device storage or gallery when you '
              'choose to save them. This data stays on your device unless you '
              'choose to share it (for example by sending feedback email).',
        ),
        _LegalSection(
          'Camera and photos',
          'If you use castle capture features, the App may access the camera '
              'and photo library with your permission. Images are processed on '
              'your device with on-device machine learning (TensorFlow Lite) to '
              'help detect tiles. Camera and photo access can be denied or '
              'revoked in your device settings; some features will then be '
              'unavailable.',
        ),
        _LegalSection(
          'Analytics and crash reporting',
          'On supported platforms the App may use Firebase services '
              '(including Analytics and Crashlytics) to understand stability '
              'and usage at a high level. These services may collect device '
              'and app diagnostic information according to Google\'s privacy '
              'practices. Some platforms (for example certain desktop builds) '
              'may not enable these services.',
        ),
        _LegalSection(
          'Feedback and logs',
          'If you use Send Feedback or attach logs, you may email the '
              'developer. Messages can include the content you write and, when '
              'attached, diagnostic log text from the App. Do not include '
              'sensitive personal information you do not want to share.',
        ),
        _LegalSection(
          'Open-source and third-party components',
          'The App uses open-source libraries (listed under Open Source '
              'Licenses), including Flutter, TensorFlow Lite, Hive, Provider, '
              'Firebase packages, camera/gallery helpers, and related tools. '
              'Those components may process data as needed to provide their '
              'features under their own licenses and policies.',
        ),
        _LegalSection(
          'Children',
          'The App is not directed at children under 13, and we do not '
              'knowingly collect personal information from children.',
        ),
        _LegalSection(
          'Your choices',
          'You can clear app data through your device settings, revoke camera '
              'or photo permissions, and choose not to send feedback or logs. '
              'Uninstalling the App removes locally stored app data on most '
              'devices.',
        ),
        _LegalSection(
          'Contact',
          'Questions about this policy can be sent via the in-app Send '
              'Feedback option to castleappraiser2@cydvicious.com.',
        ),
      ];

  List<_LegalSection> _termsSections() => const [
        _LegalSection(
          'Acceptance',
          'By using Castle Appraiser 2.0 ("the App"), you agree to these '
              'Terms of Use. If you do not agree, please do not use the App.',
        ),
        _LegalSection(
          'Unofficial companion',
          'The App is an unofficial fan-made companion for Between Two '
              'Castles of Mad King Ludwig. It is not affiliated with, endorsed '
              'by, or sponsored by Stonemaier Games or the game\'s publishers '
              'or designers. All game names, artwork, and trademarks belong to '
              'their respective owners.',
        ),
        _LegalSection(
          'License to use',
          'You may use the App for personal, non-commercial scoring and '
              'play assistance. You may not reverse engineer, redistribute, or '
              'sell the App except as allowed by applicable open-source '
              'licenses for included components, or by law.',
        ),
        _LegalSection(
          'Open-source software',
          'The App is built with Flutter and other open-source packages '
              '(including TensorFlow Lite, Hive, Provider, Firebase client '
              'libraries, camera and gallery packages, and more). Those '
              'components remain under their own licenses. Use Open Source '
              'Licenses in the App for notices required by those projects.',
        ),
        _LegalSection(
          'No warranty',
          'The App is provided "as is" without warranties of any kind, '
              'express or implied, including accuracy of scoring, fitness for '
              'a particular purpose, or uninterrupted availability. Tile '
              'detection and scoring helpers may be incomplete or incorrect.',
        ),
        _LegalSection(
          'Limitation of liability',
          'To the fullest extent permitted by law, the developer is not '
              'liable for any damages arising from your use of the App, '
              'including lost data, incorrect scores, or device issues.',
        ),
        _LegalSection(
          'Feedback',
          'If you send feedback, ideas, or logs, you grant the developer '
              'permission to use that material to improve the App without '
              'obligation to you.',
        ),
        _LegalSection(
          'Changes',
          'These terms may be updated in future app releases. Continued use '
              'after an update means you accept the revised terms.',
        ),
        _LegalSection(
          'Contact',
          'Questions about these terms can be sent via the in-app Send '
              'Feedback option to castleappraiser2@cydvicious.com.',
        ),
      ];
}

class _LegalSection {
  final String title;
  final String body;

  const _LegalSection(this.title, this.body);
}
