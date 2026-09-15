import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:bus_koi/core/constants/app_constants.dart';
import 'package:bus_koi/core/utils/name_normalizer.dart';
import 'package:bus_koi/features/community/data/community_repository.dart';
import 'package:bus_koi/shared/models/community.dart';

enum SearchResultState { empty, typing, found, notFound }

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({required CommunityRepository repository}) : _repository = repository {
    _activeSub = _repository.watchActiveCommunities().listen((value) {
      activeCommunities = value;
      notifyListeners();
    });
  }

  final CommunityRepository _repository;
  StreamSubscription<List<Community>>? _activeSub;
  Timer? _debounce;

  List<Community> activeCommunities = [];
  String query = '';
  SearchResultState resultState = SearchResultState.empty;
  Community? matchedCommunity;
  bool creating = false;
  DateTime? _lastCreatedAt;

  void onQueryChanged(String value) {
    query = value;
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      resultState = SearchResultState.empty;
      matchedCommunity = null;
      notifyListeners();
      return;
    }
    resultState = SearchResultState.typing;
    notifyListeners();

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final normalized = NameNormalizer.normalize(value);
      final match = await _repository.findActiveByNormalizedName(normalized);
      matchedCommunity = match;
      resultState = match != null ? SearchResultState.found : SearchResultState.notFound;
      notifyListeners();
    });
  }

  List<Community> get suggestions {
    if (query.trim().isEmpty) return activeCommunities;
    final normalized = NameNormalizer.normalize(query);
    return activeCommunities
        .where((c) => c.normalizedName.contains(normalized))
        .toList();
  }

  Future<Community> startOrJoin() async {
    if (matchedCommunity == null) {
      final last = _lastCreatedAt;
      if (last != null &&
          DateTime.now().difference(last) < AppConstants.minCommunityCreationGap) {
        return matchedCommunity ?? (throw StateError('rate_limited'));
      }
    }

    creating = true;
    notifyListeners();
    try {
      if (matchedCommunity != null) return matchedCommunity!;
      final community = await _repository.createCommunity(query);
      _lastCreatedAt = DateTime.now();
      return community;
    } finally {
      creating = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _activeSub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }
}
