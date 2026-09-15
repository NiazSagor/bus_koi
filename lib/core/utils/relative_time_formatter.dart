import 'package:bus_koi/core/localization/gen/app_localizations.dart';

/// "38 seconds ago" / "৩৮ সেকেন্ড আগে" — never absolute timestamps, since
/// the product only ever needs to communicate freshness.
class RelativeTimeFormatter {
  RelativeTimeFormatter._();

  static String format(AppLocalizations l10n, DateTime since, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final diff = reference.difference(since);

    if (diff.inSeconds < 5) return l10n.justNow;
    if (diff.inMinutes < 1) return l10n.secondsAgo(diff.inSeconds);
    if (diff.inHours < 1) return l10n.minutesAgo(diff.inMinutes);
    return l10n.hoursAgo(diff.inHours);
  }
}
