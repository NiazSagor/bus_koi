import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bus_koi/core/localization/gen/app_localizations.dart';
import 'package:bus_koi/core/routing/app_router.dart';
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

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vm = context.watch<HomeViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
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
              const SizedBox(height: 16),
              TextField(
                autofocus: false,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.searchHint,
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: vm.onQueryChanged,
              ),
              const SizedBox(height: 16),
              _SearchResult(vm: vm),
              const SizedBox(height: 20),
              Text(l10n.activeCommunitiesLabel, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Expanded(child: _ActiveList(vm: vm)),
            ],
          ),
        ),
      ),
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
      return const LinearProgressIndicator(minHeight: 2);
    }

    final found = vm.resultState == SearchResultState.found;
    final community = vm.matchedCommunity;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              community?.displayName ?? vm.query,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              found ? l10n.peopleWaiting(community!.activeMemberCount) : l10n.noActiveCommunityFound,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: vm.creating ? null : () => _openCommunity(context, vm),
                child: Text(found ? l10n.joinCommunity : l10n.startCommunity),
              ),
            ),
          ],
        ),
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
            leading: const Icon(Icons.directions_bus_filled_outlined),
            title: Text(community.displayName),
            subtitle: Text(l10n.peopleWaiting(community.activeMemberCount)),
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
