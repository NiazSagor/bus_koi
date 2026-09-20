import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bus_koi/core/localization/gen/app_localizations.dart';
import 'package:bus_koi/core/routing/app_router.dart';
import 'package:bus_koi/core/theme/app_theme.dart';
import 'package:bus_koi/features/community/data/community_repository.dart';
import 'package:bus_koi/features/community/presentation/community_screen.dart';
import 'package:bus_koi/features/home/presentation/home_view_model.dart';
import 'package:bus_koi/shared/models/community.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => HomeViewModel(repository: context.read<CommunityRepository>()),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vm = context.watch<HomeViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_bus_filled, color: AppTheme.demandGreen),
            const SizedBox(width: 8),
            Text(l10n.appTitle),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).pushNamed(AppRouter.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.homeTitle, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                l10n.homeTagline,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                autofocus: false,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: vm.query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            vm.onQueryChanged('');
                          },
                        ),
                ),
                onChanged: vm.onQueryChanged,
              ),
              const SizedBox(height: 16),
              _SearchResult(vm: vm),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(l10n.activeCommunitiesLabel, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 8),
                  if (vm.activeCommunities.isNotEmpty) _CountPill(count: vm.activeCommunities.length),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(child: _ActiveList(vm: vm)),
              const SizedBox(height: 12),
              _TrustStrip(text: l10n.noAccountNote),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.pillRadius),
      ),
      child: Text('$count', style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _TrustStrip extends StatelessWidget {
  const _TrustStrip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline, size: 14, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12),
        ),
      ],
    );
  }
}

class _SearchResult extends StatelessWidget {
  const _SearchResult({required this.vm});

  final HomeViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (vm.resultState == SearchResultState.empty) {
      return const SizedBox.shrink();
    }
    if (vm.resultState == SearchResultState.typing) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: const LinearProgressIndicator(minHeight: 3),
      );
    }

    final found = vm.resultState == SearchResultState.found;
    final community = vm.matchedCommunity;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BusAvatar(highlighted: found),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    community?.displayName ?? vm.query,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (found) _StatusPill(label: l10n.activeStatus),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              found ? l10n.peopleWaiting(community!.activeMemberCount) : l10n.noActiveCommunityFound,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: vm.creating ? null : () => _openCommunity(context, vm),
                icon: Icon(found ? Icons.group_add_outlined : Icons.add_circle_outline),
                label: Text(found ? l10n.joinCommunity : l10n.startCommunity),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BusAvatar extends StatelessWidget {
  const _BusAvatar({required this.highlighted});
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: highlighted
            ? AppTheme.demandGreen.withValues(alpha: 0.12)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.directions_bus_filled_outlined,
        color: highlighted ? AppTheme.demandGreen : Theme.of(context).colorScheme.outline,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.demandGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, size: 8, color: AppTheme.demandGreen),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.demandGreen,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveList extends StatelessWidget {
  const _ActiveList({required this.vm});

  final HomeViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = vm.suggestions;

    if (items.isEmpty) {
      return Center(
        child: Text(
          l10n.noActiveCommunitiesYet,
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final community = items[index];
        return Card(
          child: ListTile(
            leading: const _BusAvatar(highlighted: false),
            title: Text(community.displayName),
            subtitle: Text(l10n.peopleWaiting(community.activeMemberCount)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _navigateToCommunity(context, community),
          ),
        );
      },
    );
  }
}

Future<void> _openCommunity(BuildContext context, HomeViewModel vm) async {
  final community = await vm.startOrJoin();
  if (!context.mounted) return;
  _navigateToCommunity(context, community);
}

void _navigateToCommunity(BuildContext context, Community community) {
  Navigator.of(context).pushNamed(
    AppRouter.community,
    arguments: CommunityScreenArgs(
      communityId: community.id,
      displayName: community.displayName,
    ),
  );
}
