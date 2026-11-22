import 'package:flutter/material.dart';

import '../data/app_repository.dart';

/// Provides the single [AppRepository] instance to the widget tree.
class AppScope extends InheritedNotifier<AppRepository> {
  const AppScope({
    super.key,
    required AppRepository repository,
    required super.child,
  }) : super(notifier: repository);

  static AppRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!.notifier!;
  }
}
