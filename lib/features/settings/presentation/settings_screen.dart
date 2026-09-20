import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bus_koi/core/localization/gen/app_localizations.dart';
import 'package:bus_koi/core/theme/app_theme.dart';
import 'package:bus_koi/features/settings/presentation/app_settings_provider.dart';
import 'package:bus_koi/features/settings/presentation/locale_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeProvider = context.watch<LocaleProvider>();
    final settings = context.watch<AppSettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeroTrustCard(title: l10n.privacyInfoTitle, body: l10n.privacyInfoBody),
          const SizedBox(height: 16),
          _SectionCard(
            title: l10n.language,
            icon: Icons.translate_outlined,
            child: RadioGroup<Locale?>(
              groupValue: localeProvider.locale,
              onChanged: (value) => localeProvider.setLocale(value),
              child: Column(
                children: [
                  RadioListTile<Locale?>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.systemDefault),
                    value: null,
                  ),
                  RadioListTile<Locale?>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.english),
                    value: const Locale('en'),
                  ),
                  RadioListTile<Locale?>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.bengali),
                    value: const Locale('bn'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: l10n.textSize,
            icon: Icons.format_size,
            child: SegmentedButton<TextSizeOption>(
              segments: [
                ButtonSegment(value: TextSizeOption.small, label: Text(l10n.textSizeSmall)),
                ButtonSegment(value: TextSizeOption.standard, label: Text(l10n.textSizeStandard)),
                ButtonSegment(value: TextSizeOption.large, label: Text(l10n.textSizeLarge)),
              ],
              selected: {settings.textSize},
              onSelectionChanged: (selection) => settings.setTextSize(selection.first),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: l10n.dataAndBattery,
            icon: Icons.battery_saver_outlined,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.batterySaverTitle),
                  subtitle: Text(l10n.batterySaverBody),
                  value: settings.batterySaver,
                  onChanged: settings.setBatterySaver,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.dataSaverTitle),
                  subtitle: Text(l10n.dataSaverBody),
                  value: settings.dataSaver,
                  onChanged: settings.setDataSaver,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: l10n.about,
            icon: Icons.info_outline,
            child: Text(l10n.aboutBody),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: l10n.communityConductTitle,
            icon: Icons.groups_outlined,
            child: Text(l10n.communityConductBody),
          ),
        ],
      ),
    );
  }
}

class _HeroTrustCard extends StatelessWidget {
  const _HeroTrustCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.demandGreen.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.verified_user_outlined, color: AppTheme.demandGreen),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.demandGreen,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
