# Yayın Hazırlığı: Senin Yapman Gerekenler

Kod tarafındaki zorunlu işler yapıldı. Aşağıdaki adımlar şifre, hesap veya web sitesi gerektirdiği için senin elinde.

## 1. Uygulama kimliği

Uygulamanın kimliği `com.acici.butce` oldu (Android ve iPhone). Başka bir ad istersen yayından **önce** değiştir; yayından sonra değiştirilemez.

Kimlik değiştiği için telefonuna yeni sürüm ayrı bir uygulama olarak kurulur. Eski deneme sürümündeki kişisel kayıtları taşımak için: eski uygulamaya da yedekleme özelliği gelmediğinden, kayıtların önemliyse eski uygulamayı silmeden önce ortak bütçeye aktar ya da yeniden gir.

## 2. İmza anahtarı (bir kez yapılır)

Windows'ta PowerShell'i aç ve şunu çalıştır (Android Studio ile gelen `keytool` kullanılır):

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v `
  -keystore "$env:USERPROFILE\acici-budget-upload.jks" `
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Sorulan şifreyi güçlü seç ve bir şifre yöneticisine kaydet.

Sonra `android/key.properties` adında bir dosya oluştur:

```
storePassword=BURAYA_ŞİFRE
keyPassword=BURAYA_ŞİFRE
keyAlias=upload
storeFile=C:/Users/cigdem.uysal/acici-budget-upload.jks
```

Bu iki dosya (`.jks` ve `key.properties`) git'e eklenmez. **`.jks` dosyasını mutlaka ikinci bir yere yedekle** (ör. şifreli bir USB veya şifre yöneticisi). Google Play App Signing açıksa kaybı telafi edilebilir ama uğraştırır.

Mağaza dosyasını oluşturmak için:

```powershell
flutter build appbundle --release `
  --dart-define=SUPABASE_URL=https://PROJE.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_... `
  --dart-define=SENTRY_DSN=https://...ingest.de.sentry.io/...
```

`SENTRY_DSN` satırı 5. adımda anlatılan çökme raporlaması içindir; eklemezsen rapor gönderilmez.

Çıkan dosya: `build/app/outputs/bundle/release/app-release.aab`.

## 3. Supabase'te yeni SQL dosyasını çalıştır

Hesap silme özelliğinin çalışması için Supabase SQL Editor'da şu dosyanın tamamını çalıştır:

`supabase/migrations/202610120001_delete_own_account.sql`

Çalıştırmazsan "Hesabımı sil" düğmesi uyarı verir, hiçbir şey silinmez.

## 4. Gizlilik politikası ve kullanım koşulları

Taslaklar hazır:
- Uygulama içinde: `assets/legal/gizlilik_politikasi.txt` ve `assets/legal/kullanim_kosullari.txt`
- Web için: `docs/gizlilik-politikasi.html`

Yapman gerekenler:
1. Köşeli parantezli yerleri doldur: `[GELİŞTİRİCİ ADI SOYADI / ŞİRKET UNVANI]`, `[İLETİŞİM E-POSTASI]`, `[TARİH]`, `[SUNUCU BÖLGESİ]`, `[GİZLİLİK POLİTİKASI WEB ADRESİ]`. Sunucu bölgesini Supabase panelinde Project Settings > General bölümünde görebilirsin.
2. Aynı bilgileri hem `.txt` dosyalarına hem `.html` dosyasına yaz.
3. `docs/gizlilik-politikasi.html` dosyasını herkese açık bir adreste yayınla. Ücretsiz seçenekler: GitHub Pages, Google Sites veya Netlify Drop (dosyayı sürükleyip bırakman yeterli).
4. Bu adresi Google Play Console'da "Gizlilik politikası" alanına gir.
5. Metinler bir avukat tarafından kontrol edilmedi. Uygulamadan para kazanmayı planlıyorsan bir avukata baktırman iyi olur.

## 5. Çökme raporlaması (Sentry)

Uygulama, kullanıcıların telefonunda bir hata olduğunda bunu sana bildirebilir. Bunun için:

1. [sentry.io](https://sentry.io) adresinde ücretsiz hesap aç. Kayıtta veri bölgesi olarak **EU (Frankfurt)** seç.
2. Yeni proje oluştururken platform olarak **Flutter** seç.
3. Proje ayarlarında Security & Privacy bölümünden **Prevent Storing of IP Addresses** seçeneğini aç. **Data Scrubber** seçeneğinin açık olduğunu kontrol et.
4. Proje ayarlarındaki Client Keys (DSN) bölümünden DSN adresini kopyala ve yukarıdaki build komutunda `SENTRY_DSN=` kısmına yapıştır.
5. Gizlilik metnindeki `[SENTRY VERİ BÖLGESİ]` ve `[SENTRY SAKLAMA SÜRESİ]` alanlarını doldur. Ücretsiz planda saklama süresi 30 gündür.

DSN verilmezse uygulama hiçbir rapor göndermez. Deneme yaparken bunu boş bırakabilirsin.

## 6. Google Play Console ayarları

- **Veri güvenliği formu:** E-posta adresi ve finansal bilgiler (ortak bütçe kullananlar için) ile çökme kayıtları ve tanılama verileri (Sentry açıksa) toplanıyor. Hepsi aktarım sırasında şifreleniyor ve kullanıcı silme isteğinde bulunabiliyor. Reklam ve kullanım analizi yok.
- **Hesap silme bağlantısı:** Play Console bir web adresi de istiyor. Gizlilik politikası sayfasındaki "Verilerimi nasıl silerim?" bölümü bu iş için kullanılabilir.
- **Kapalı test:** Yeni kişisel geliştirici hesaplarında herkese açık yayından önce en az 12 kişiyle 14 gün kapalı test şartı var.

## 7. Yayından önce telefonda dene

1. İnternet açıkken ortak bütçeye bir gider ekle, diğer telefonda göründüğünü kontrol et.
2. Uçak modunu aç, gider ekle ve sil. Üstte "İnternet bağlantısı yok" uyarısı çıkmalı.
3. Uçak modunu kapat. En geç 30 saniye içinde değişiklikler gönderilmeli ve diğer telefonda görünmeli.
4. Ayarlar > Yedek al ile dosya oluştur, ardından Yedeği geri yükle ile aynı dosyayı yükle.
5. Deneme hesabıyla "Hesabımı sil"i dene.
