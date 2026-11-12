/// File Name: group_provider.dart
/// Description: Riverpod provider for groups state.
/// Author: Keefe Chen
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/group_model.dart';
import 'data/group_repository.dart';

final groupRepositoryProvider = Provider((ref) => GroupRepository());

final groupProvider = FutureProvider.autoDispose<List<GroupModel>>((ref) {
  final repo = ref.watch(groupRepositoryProvider);
  return repo.fetchAll();
});
