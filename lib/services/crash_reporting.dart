import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Çökme ve hata raporlama (Sentry).
///
/// Uygulama `--dart-define=SENTRY_DSN=...` ile başlatılmazsa hiçbir rapor
/// gönderilmez ve uygulama eskisi gibi çalışır. Raporlara kişisel veri
/// eklenmez: e-posta, IP adresi, ekran görüntüsü, ağ istekleri ve
/// kullanıcının girdiği tutarlar gönderilmez; yalnızca hatanın türü,
/// kod içindeki yeri, uygulama sürümü ve cihaz modeli gider.
class CrashReporting {
  CrashReporting._();

  static const String _dsn = String.fromEnvironment('SENTRY_DSN');

  static bool get isEnabled => _dsn.isNotEmpty;

  /// [appRunner]'ı çalıştırır; Sentry ayarlıysa önce onu başlatır.
  static Future<void> run(Future<void> Function() appRunner) async {
    if (!isEnabled) {
      await appRunner();
      return;
    }
    await SentryFlutter.init((options) {
      options.dsn = _dsn;
      options.environment = kReleaseMode ? 'production' : 'debug';
      options.sendDefaultPii = false;
      options.attachScreenshot = false;
      options.attachViewHierarchy = false;
      options.tracesSampleRate = 0;
      options.beforeBreadcrumb = _scrubBreadcrumb;
      options.beforeSend = _scrubEvent;
    }, appRunner: appRunner);
  }

  /// Ağ isteği ve ekrana yazılan metin kayıtları kişisel veri (ör. ortak
  /// bütçe kimliği, tutarlar) içerebileceği için gönderilmez.
  static Breadcrumb? _scrubBreadcrumb(Breadcrumb? breadcrumb, Hint hint) {
    if (breadcrumb == null) return null;
    const dropped = {'http', 'ui.click', 'console', 'navigation'};
    if (dropped.contains(breadcrumb.category) || breadcrumb.type == 'http') {
      return null;
    }
    return breadcrumb;
  }

  static SentryEvent? _scrubEvent(SentryEvent event, Hint hint) {
    event.user = null;
    event.request = null;
    event.serverName = null;
    return event;
  }

  /// Kullanıcıya mesajla gösterilen ama geliştiricinin bilmesi gereken
  /// hataları kaydeder. Sentry ayarlı değilse hiçbir şey yapmaz.
  static Future<void> report(Object error, StackTrace stackTrace) async {
    if (!isEnabled) return;
    await Sentry.captureException(error, stackTrace: stackTrace);
  }
}
