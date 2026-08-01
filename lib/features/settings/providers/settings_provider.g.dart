// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appSettingsHash() => r'962b90b18f5c6f3ee91b1facfda1d1260d080f6b';

/// See also [appSettings].
@ProviderFor(appSettings)
final appSettingsProvider = AutoDisposeFutureProvider<AppSettings?>.internal(
  appSettings,
  name: r'appSettingsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$appSettingsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AppSettingsRef = AutoDisposeFutureProviderRef<AppSettings?>;
String _$settingsNotifierHash() => r'1fb8d4dd95a2d0d7a36138eef79de124a8851585';

/// See also [SettingsNotifier].
@ProviderFor(SettingsNotifier)
final settingsNotifierProvider =
    AutoDisposeAsyncNotifierProvider<SettingsNotifier, AppSettings>.internal(
  SettingsNotifier.new,
  name: r'settingsNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$settingsNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SettingsNotifier = AutoDisposeAsyncNotifier<AppSettings>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
