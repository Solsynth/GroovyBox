import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
// Loaded directly: easy_localization does not export its Localization class,
// and the singleton must be populated before any test body runs.
// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';

/// Runs before every test file in this directory.
///
/// The app resolves strings through easy_localization's context-free `tr()`,
/// which reads a process-wide singleton. Loading the real en-US catalog here
/// means every widget test sees the same text the app ships, without wrapping
/// each pump in an `EasyLocalization` widget.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final catalog =
      jsonDecode(File('assets/i18n/en-US.json').readAsStringSync())
          as Map<String, dynamic>;
  Localization.load(
    const Locale('en', 'US'),
    translations: Translations(catalog),
  );
  await testMain();
}
