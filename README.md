# Açıcı Budget

Gelir, gider, taksit ve yatırım takibi yapan; isteğe bağlı olarak iki kişinin ortak bütçe tutmasına izin veren Flutter uygulaması.

## Çalıştırma

```powershell
flutter pub get
flutter run
```

Ortak bütçe için Supabase ayarları: [SHARED_BUDGET_SETUP.md](SHARED_BUDGET_SETUP.md)
Mağazaya çıkış adımları: [YAYIN_HAZIRLIGI.md](YAYIN_HAZIRLIGI.md)

İsteğe bağlı başlatma ayarları (`--dart-define`):

| Ayar | Ne işe yarar |
| --- | --- |
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` | Ortak bütçeyi açar. Verilmezse uygulama yalnızca telefondaki veritabanıyla çalışır. |
| `SENTRY_DSN` | Çökme raporlamayı açar. Verilmezse hiçbir rapor gönderilmez. |

## Testler

```powershell
flutter test
```

Testler bütçe hesaplarını (aylık bakiye, devir, taksit, yatırım kâr/zararı), para biçimini, yedekleme dosyasını, telefondaki veritabanını ve internetsiz ortak bütçe sırasını kontrol eder. Yeni bir hesaplama eklerken `test/budget_calculator_test.dart` dosyasına test eklemek iyi olur.

## Kod yapısı

```
lib/
  main.dart                 Uygulamayı başlatır
  app.dart                  Tema ve bağlantı (davet linki) yönlendirmesi
  models/                   Gider, gelir, taksit, yatırım veri modelleri
  logic/budget_calculator.dart
                            Bakiye, devir, taksit ve yatırım hesapları (ekrandan bağımsız)
  services/
    database_helper.dart    Telefondaki SQLite veritabanı, yedekleme
    shared_budget_service.dart
                            Supabase ortak bütçe ve internetsiz çalışma
    tcmb_rates_service.dart TCMB döviz kurları
    crash_reporting.dart    Sentry çökme raporlama
  pages/
    root_page.dart          Alt menü, veri yükleme ve ekle/düzenle/sil işlemleri
    overview_tab.dart       Ana sayfa
    installments_tab.dart   Taksitler sekmesi
    investments_tab.dart    Yatırımlar sekmesi
    add_*_page.dart         Ekleme ve düzenleme formları
    shared_budget_page.dart Ortak sekmesi (giriş, davet, hesap silme)
    settings_page.dart      Ayarlar (yedek, yasal metinler, veri silme)
  utils/
    constants.dart          Kategoriler, ay adları, tarih yardımcıları
    formatting.dart         Türkçe para ve sayı biçimi
supabase/migrations/        Supabase'te çalıştırılacak SQL dosyaları
assets/legal/               Uygulama içindeki gizlilik politikası ve kullanım koşulları
docs/                       Web'de yayınlanacak gizlilik politikası
```
