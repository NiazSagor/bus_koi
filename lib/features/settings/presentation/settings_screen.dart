import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bus_koi/core/localization/gen/app_localizations.dart';
import 'package:bus_koi/features/settings/presentation/locale_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeProvider = context.watch<LocaleProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.language, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          RadioGroup<Locale?>(
            groupValue: localeProvider.locale,
            onChanged: (value) => localeProvider.setLocale(value),
            child: Column(
              children: [
                RadioListTile<Locale?>(
                  title: Text(l10n.systemDefault),
                  value: null,
                ),
                RadioListTile<Locale?>(
                  title: Text(l10n.english),
                  value: const Locale('en'),
                ),
                RadioListTile<Locale?>(
                  title: Text(l10n.bengali),
                  value: const Locale('bn'),
                ),
              ],
            ),
          ),
          const Divider(height: 32),
          Text(l10n.privacyInfoTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(l10n.privacyInfoBody),
          const Divider(height: 32),
          Text(l10n.about, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(l10n.aboutBody),
        ],
      ),
    );
  }
}
