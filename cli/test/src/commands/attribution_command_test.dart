import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:somnio/src/commands/attribution_command.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmpDir;
  late String settingsPath;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('attribution_command_test_');
    settingsPath = p.join(tmpDir.path, '.claude', 'settings.json');
  });

  tearDown(() => tmpDir.deleteSync(recursive: true));

  Map<String, dynamic> readSettings() =>
      jsonDecode(File(settingsPath).readAsStringSync()) as Map<String, dynamic>;

  void writeSettings(Object settings) {
    File(settingsPath)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(settings));
  }

  group('setClaudeAttribution off', () {
    test('creates settings.json with empty commit and PR attribution', () {
      final changed = setClaudeAttribution(settingsPath, enabled: false);

      expect(changed, isTrue);
      expect(readSettings()['attribution'], {'commit': '', 'pr': ''});
    });

    test('preserves existing settings keys', () {
      writeSettings({
        'env': {'FOO': 'bar'},
        'hooks': {'Stop': <Object>[]},
      });

      setClaudeAttribution(settingsPath, enabled: false);

      final settings = readSettings();
      expect(settings['env'], {'FOO': 'bar'});
      expect(settings['hooks'], {'Stop': <Object>[]});
      expect(settings['attribution'], {'commit': '', 'pr': ''});
    });

    test('replaces a custom attribution', () {
      writeSettings({
        'attribution': {'commit': 'Made with AI', 'pr': ''},
      });

      final changed = setClaudeAttribution(settingsPath, enabled: false);

      expect(changed, isTrue);
      expect(readSettings()['attribution'], {'commit': '', 'pr': ''});
    });

    test('is idempotent', () {
      setClaudeAttribution(settingsPath, enabled: false);
      final before = File(settingsPath).readAsStringSync();

      final changed = setClaudeAttribution(settingsPath, enabled: false);

      expect(changed, isFalse);
      expect(File(settingsPath).readAsStringSync(), before);
    });

    test('treats an empty settings file as empty settings', () {
      File(settingsPath)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('');

      setClaudeAttribution(settingsPath, enabled: false);

      expect(readSettings(), {
        'attribution': {'commit': '', 'pr': ''},
      });
    });

    test('throws and leaves a malformed settings file untouched', () {
      File(settingsPath)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('{ not json');

      expect(
        () => setClaudeAttribution(settingsPath, enabled: false),
        throwsFormatException,
      );
      expect(File(settingsPath).readAsStringSync(), '{ not json');
    });

    test('throws when settings.json is not a JSON object', () {
      writeSettings(<Object>[]);

      expect(
        () => setClaudeAttribution(settingsPath, enabled: false),
        throwsFormatException,
      );
      expect(File(settingsPath).readAsStringSync(), '[]');
    });
  });

  group('setClaudeAttribution on', () {
    test('removes the attribution key and keeps the rest', () {
      writeSettings({
        'tui': 'fullscreen',
        'attribution': {'commit': '', 'pr': ''},
      });

      final changed = setClaudeAttribution(settingsPath, enabled: true);

      expect(changed, isTrue);
      expect(readSettings(), {'tui': 'fullscreen'});
    });

    test('does nothing when attribution is already the default', () {
      final changed = setClaudeAttribution(settingsPath, enabled: true);

      expect(changed, isFalse);
      expect(File(settingsPath).existsSync(), isFalse);
    });
  });

  group('readClaudeAttribution', () {
    test('is enabled when settings.json does not exist', () {
      expect(
        readClaudeAttribution(settingsPath),
        ClaudeAttributionState.enabled,
      );
    });

    test('is disabled when commit and PR attribution are empty', () {
      writeSettings({
        'attribution': {'commit': '', 'pr': ''},
      });

      expect(
        readClaudeAttribution(settingsPath),
        ClaudeAttributionState.disabled,
      );
    });

    test('is custom when only one side is empty', () {
      writeSettings({
        'attribution': {'commit': '', 'pr': 'Made with AI'},
      });

      expect(
        readClaudeAttribution(settingsPath),
        ClaudeAttributionState.custom,
      );
    });
  });
}
