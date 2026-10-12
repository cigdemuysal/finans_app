import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'database_helper.dart';
import 'shared_budget_service.dart';

/// Yedekleme, geri yükleme, veri silme ve yasal metinler.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.onDataChanged});

  /// Kayıtlar değiştiğinde ana ekranın yenilenmesi için çağrılır.
  final Future<void> Function() onDataChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _busy = false;

  static const _backupFormat = 'acici-budget-backup';
  static const _backupVersion = 1;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createBackup() async {
    await _run(() async {
      try {
        final tables = await DatabaseHelper.instance.exportPersonalData();
        final count = tables.values.fold<int>(0, (t, rows) => t + rows.length);
        if (count == 0) {
          _showMessage('Bu cihazda yedeklenecek kişisel kayıt yok.');
          return;
        }
        final now = DateTime.now();
        final backup = {
          'format': _backupFormat,
          'version': _backupVersion,
          'createdAt': now.toIso8601String(),
          'tables': tables,
        };
        final bytes = Uint8List.fromList(
          utf8.encode(const JsonEncoder.withIndent('  ').convert(backup)),
        );
        final stamp =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-'
            '${now.day.toString().padLeft(2, '0')}';
        final saved = await FilePicker.saveFile(
          dialogTitle: 'Yedeği kaydet',
          fileName: 'acici-budget-yedek-$stamp.json',
          bytes: bytes,
          mimeType: 'application/json',
          type: FileType.custom,
          allowedExtensions: const ['json'],
        );
        if (saved == null) return;
        _showMessage('$count kayıt yedeklendi.');
      } catch (_) {
        _showMessage('Yedek oluşturulamadı. Lütfen tekrar deneyin.');
      }
    });
  }

  Future<void> _restoreBackup() async {
    final PlatformFile? file;
    try {
      file = await FilePicker.pickFile(
        dialogTitle: 'Yedek dosyasını seç',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
    } catch (_) {
      _showMessage('Dosya seçilemedi.');
      return;
    }
    if (file == null || !mounted) return;

    final Map<String, List<Map<String, dynamic>>> tables;
    try {
      final decoded = jsonDecode(utf8.decode(await file.xFile.readAsBytes()));
      tables = parseBackup(decoded);
    } catch (_) {
      _showMessage('Bu dosya geçerli bir Açıcı Budget yedeği değil.');
      return;
    }
    final count = tables.values.fold<int>(0, (t, rows) => t + rows.length);
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yedeği geri yükle'),
        content: Text(
          'Bu cihazdaki kişisel kayıtlar silinecek ve yerine yedekteki '
          '$count kayıt yüklenecek. Ortak bütçe etkilenmez. Devam edilsin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Geri yükle'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _run(() async {
      try {
        final restored = await DatabaseHelper.instance.replacePersonalData(
          tables,
        );
        await widget.onDataChanged();
        _showMessage('$restored kayıt geri yüklendi.');
      } catch (_) {
        _showMessage(
          'Yedek geri yüklenemedi. Mevcut kayıtlarınız değiştirilmedi.',
        );
      }
    });
  }

  Future<void> _deletePersonalData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bu cihazdaki kayıtları sil'),
        content: const Text(
          'Bu cihazdaki tüm kişisel gelir, gider, taksit ve yatırım kayıtları '
          'kalıcı olarak silinecek. Bu işlem geri alınamaz. Önce yedek almanızı '
          'öneririz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kalıcı olarak sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      await DatabaseHelper.instance.deleteAllPersonalData();
      await widget.onDataChanged();
      _showMessage('Bu cihazdaki kişisel kayıtlar silindi.');
    });
  }

  void _openLegalText(String title, String assetPath) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => LegalTextPage(title: title, assetPath: assetPath),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sharedActive = SharedBudgetService.hasActiveSharedBudget;
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        children: [
          if (_busy) const LinearProgressIndicator(),
          const _SectionTitle('Yedekleme'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              sharedActive
                  ? 'Yedek bu cihazdaki kişisel kayıtları içerir. Ortak bütçe '
                        'kayıtları bulutta saklanır.'
                  : 'Telefonunuz kaybolursa veya uygulamayı silerseniz kayıtlarınız '
                        'da gider. Düzenli olarak yedek alıp Google Drive gibi bir '
                        'yere kaydetmenizi öneririz.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Yedek al'),
            subtitle: const Text('Kayıtlarınızı bir dosyaya kaydedin'),
            enabled: !_busy,
            onTap: _createBackup,
          ),
          ListTile(
            leading: const Icon(Icons.settings_backup_restore),
            title: const Text('Yedeği geri yükle'),
            subtitle: const Text('Daha önce aldığınız yedeği yükleyin'),
            enabled: !_busy,
            onTap: _restoreBackup,
          ),
          const Divider(),
          const _SectionTitle('Yasal'),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Gizlilik politikası'),
            onTap: () => _openLegalText(
              'Gizlilik Politikası',
              'assets/legal/gizlilik_politikasi.txt',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Kullanım koşulları'),
            onTap: () => _openLegalText(
              'Kullanım Koşulları',
              'assets/legal/kullanim_kosullari.txt',
            ),
          ),
          const Divider(),
          const _SectionTitle('Veriler'),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              'Bu cihazdaki kayıtları sil',
              style: TextStyle(color: Colors.red),
            ),
            subtitle: const Text(
              'Hesabınızı silmek için Ortak sekmesine gidin.',
            ),
            enabled: !_busy,
            onTap: _deletePersonalData,
          ),
        ],
      ),
    );
  }
}

/// Yedek dosyasını okur ve doğrular. Geçersizse [FormatException] fırlatır.
Map<String, List<Map<String, dynamic>>> parseBackup(Object? decoded) {
  if (decoded is! Map ||
      decoded['format'] != _SettingsPageState._backupFormat ||
      decoded['tables'] is! Map) {
    throw const FormatException('Yedek biçimi tanınmadı.');
  }
  final version = decoded['version'];
  if (version is! int || version > _SettingsPageState._backupVersion) {
    throw const FormatException('Bu yedek daha yeni bir sürümle alınmış.');
  }
  const allowedTables = ['expenses', 'incomes', 'installments', 'investments'];
  final tables = decoded['tables'] as Map;
  return {
    for (final table in allowedTables)
      table: [
        for (final row in (tables[table] as List?) ?? const [])
          if (row is Map)
            Map<String, dynamic>.from(row)
          else
            throw const FormatException('Bozuk kayıt.'),
      ],
  };
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

/// Uygulamayla birlikte gelen yasal metinleri gösterir.
class LegalTextPage extends StatelessWidget {
  const LegalTextPage({
    super.key,
    required this.title,
    required this.assetPath,
  });

  final String title;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(assetPath),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Metin yüklenemedi.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(snapshot.data!),
          );
        },
      ),
    );
  }
}
