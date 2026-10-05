# Ortak Bütçe Kurulumu

Uygulama Supabase yapılandırılmadığında mevcut SQLite veritabanıyla çalışmaya
devam eder. Ortak bütçeyi açmak için:

1. Supabase'te bir proje oluşturun.
2. `supabase/migrations` klasöründeki SQL dosyalarını tarih sırasıyla Supabase
   SQL Editor'de çalıştırın. Yeni kurulumda önce
   `202609280001_shared_budgets.sql`, ardından
   `202610040001_household_member_emails.sql` ve
   `202610040002_limit_household_invites.sql` dosyalarını çalıştırın. Mevcut
   kurulumda yalnızca henüz çalıştırmadığınız migration dosyalarını çalıştırın.
3. Supabase Authentication ayarlarından e-posta ile kayıt/girişi açın. E-posta
   doğrulaması etkinse **Authentication → URL Configuration → Additional
   Redirect URLs** listesine `acici-budget://auth-callback` ekleyin. Kayıt
   doğrulama bağlantısı onaylandıktan sonra uygulamayı açar.
4. Supabase Project URL ve publishable key değerlerini kullanarak uygulamayı
   başlatın:

   ```powershell
   flutter run --dart-define=SUPABASE_URL=https://PROJECT_REF.supabase.co `
     --dart-define=SUPABASE_ANON_KEY=sb_publishable_...
   ```

   Publishable key mobil uygulamada kullanılmak içindir. `service_role` veya
   secret key'i istemciye koymayın. Veriye erişimi SQL migration'daki RLS
   kuralları sınırlar.

5. VS Code'da **Run and Debug** bölümünden `Açıcı Budget (Supabase)` profilini
   seçin. Bu profil `.vscode/launch.json` içindeki Project URL ve publishable
   key değerlerini kullanır. İki cihazda da aynı Supabase projesini kullanın.
6. Uygulamada **Ortak** sekmesine gidin. İlk kişi hesap oluşturup ortak bütçe
   kurar; ekrandaki davet bağlantısını partnerine yollar. İkinci kişi kendi
   hesabını oluşturup bağlantıyı açar (veya davet kodunu girer).
7. Önceden girilmiş yerel kayıtlar paylaşılmaz. İsteyen kullanıcı, ortak bütçe
   ekranındaki açık onay adımıyla kendi cihazındaki kayıtları bir defa ortak
   alana kopyalayabilir. İçe aktarma aynı yerel kayıt için tekrarlandığında
   mükerrer kayıt oluşturmaz.

Ortak bütçe etkin durumdayken gelir, gider, taksit ve yatırım kayıtları buluttan
okunup buluta yazılır ve diğer cihazdaki değişiklikler anlık yenilenir. Çevrimdışı
yazma ve sonradan eşitleme henüz eklenmemiştir. Kişisel kayıtlar cihazın SQLite
veritabanında kalır.
