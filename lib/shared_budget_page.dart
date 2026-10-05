import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'database_helper.dart';
import 'shared_budget_service.dart';

class SharedBudgetPage extends StatefulWidget {
  const SharedBudgetPage({
    super.key,
    this.initialInviteCode,
    this.onSharedBudgetChanged,
    this.onBack,
  });

  final String? initialInviteCode;
  final Future<void> Function()? onSharedBudgetChanged;
  final VoidCallback? onBack;

  @override
  State<SharedBudgetPage> createState() => _SharedBudgetPageState();
}

class _SharedBudgetPageState extends State<SharedBudgetPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController(text: 'Ortak Bütçemiz');
  final _inviteCode = TextEditingController();

  bool _isRegistering = false;
  bool _busy = false;
  String? _householdId;
  int _householdMemberCount = 1;
  List<String> _otherMemberEmails = [];
  bool _otherMembersLoadFailed = false;
  String? _inviteCodeForDisplay;
  String? _inviteLinkForDisplay;

  bool get _signedIn => SharedBudgetService.client?.auth.currentUser != null;

  @override
  void initState() {
    super.initState();
    _householdId = SharedBudgetService.activeHouseholdId;
    _inviteCode.text = widget.initialInviteCode ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreSignedInHousehold();
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _inviteCode.dispose();
    super.dispose();
  }

  Future<void> _perform(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('SocketFailed host lookup') ||
        message.contains('Failed host lookup') ||
        message.contains('No address associated with hostname') ||
        message.contains('SocketException') ||
        message.contains('Connection timed out')) {
      return 'Supabase sunucusuna ulaşılamadı. Emülatörün internet bağlantısını '
          'kontrol edip tekrar deneyin. Kayıt isteği sunucuya gönderilemedi.';
    }
    if (message.contains('Invalid login credentials')) {
      return 'E-posta veya şifre hatalı.';
    }
    if (message.contains('User already registered')) {
      return 'Bu e-posta adresi zaten kayıtlı. Giriş yapmayı deneyin.';
    }
    if (message.contains('Davet kodu geçersiz')) {
      return 'Davet kodu geçersiz veya süresi dolmuş.';
    }
    return message.replaceFirst('Exception: ', '');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _authenticate() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      _showMessage('Lütfen e-posta adresinizi girin.');
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      _showMessage('Lütfen geçerli bir e-posta adresi girin.');
      return;
    }
    if (_password.text.isEmpty) {
      _showMessage('Lütfen şifrenizi girin.');
      return;
    }
    if (_password.text.length < 6) {
      _showMessage('Şifre en az 6 karakter olmalı.');
      return;
    }

    await _perform(() async {
      final client = SharedBudgetService.client!;
      if (_isRegistering) {
        final response = await client.auth.signUp(
          email: email,
          password: _password.text,
          emailRedirectTo: SharedBudgetService.authRedirectUrl,
        );
        if (response.session == null) {
          _showMessage('E-postanıza gelen doğrulama bağlantısını açın.');
          return;
        }
      } else {
        await client.auth.signInWithPassword(
          email: email,
          password: _password.text,
        );
      }
      final householdId = await SharedBudgetService.getCurrentUserHouseholdId();
      await _setActiveHousehold(householdId);
      if (householdId == null && _inviteCode.text.trim().isNotEmpty) {
        _showMessage('Giriş tamamlandı. Şimdi davet koduyla katılabilirsiniz.');
      }
    });
  }

  Future<void> _restoreSignedInHousehold() async {
    if (!_signedIn) return;
    try {
      final householdId = await SharedBudgetService.getCurrentUserHouseholdId();
      if (!mounted) return;
      if (householdId != _householdId) {
        await _setActiveHousehold(householdId);
      } else {
        await _loadOtherMembers();
      }
    } catch (error) {
      if (mounted) _showMessage(_friendlyError(error));
    }
  }

  Future<void> _createHousehold() async {
    if (_name.text.trim().isEmpty) {
      _showMessage('Ortak bütçeye bir ad verin.');
      return;
    }
    await _perform(() async {
      final id = await SharedBudgetService.createHousehold(_name.text);
      await _setActiveHousehold(id);
      final code = await SharedBudgetService.createInvite(id);
      if (mounted) {
        setState(() {
          _inviteCodeForDisplay = code;
          _inviteLinkForDisplay = _createInviteLink(code);
        });
      }
      _showMessage('Ortak bütçe oluşturuldu. Kodu diğer kişiyle paylaşın.');
    });
  }

  Future<void> _joinHousehold() async {
    if (_inviteCode.text.trim().isEmpty) {
      _showMessage('Katılmak için davet kodunu girin.');
      return;
    }
    await _perform(() async {
      final id = await SharedBudgetService.joinHousehold(_inviteCode.text);
      await _setActiveHousehold(id);
      _inviteCode.clear();
      _showMessage('Ortak bütçeye katıldınız.');
    });
  }

  Future<void> _setActiveHousehold(String? id) async {
    await DatabaseHelper.instance.setActiveHouseholdId(id);
    await DatabaseHelper.instance.setSharedModeEnabled(id != null);
    SharedBudgetService.activeHouseholdId = id;
    SharedBudgetService.sharedModeEnabled = id != null;
    await widget.onSharedBudgetChanged?.call();
    if (!mounted) return;
    setState(() {
      _householdId = SharedBudgetService.activeHouseholdId;
      _householdMemberCount = id == null ? 0 : 1;
      _otherMemberEmails = [];
      _otherMembersLoadFailed = false;
      _inviteCodeForDisplay = null;
      _inviteLinkForDisplay = null;
    });
    await _loadOtherMembers();
  }

  Future<void> _loadOtherMembers() async {
    final id = _householdId;
    if (id == null || !SharedBudgetService.hasActiveSharedBudget) return;
    try {
      final count = await SharedBudgetService.getHouseholdMemberCount(id);
      if (!mounted || _householdId != id) return;
      if (count == 0) {
        await _setActiveHousehold(null);
        return;
      }
      setState(() => _householdMemberCount = count);

      final emails = await SharedBudgetService.getOtherHouseholdMemberEmails(
        id,
      );
      if (!mounted || _householdId != id) return;
      setState(() {
        _otherMemberEmails = emails;
        _otherMembersLoadFailed = false;
      });
    } catch (_) {
      if (!mounted || _householdId != id) return;
      setState(() => _otherMembersLoadFailed = true);
    }
  }

  Future<void> _refreshInvite() async {
    final id = _householdId;
    if (id == null) return;
    await _perform(() async {
      final code = await SharedBudgetService.createInvite(id);
      if (mounted) {
        setState(() {
          _inviteCodeForDisplay = code;
          _inviteLinkForDisplay = _createInviteLink(code);
        });
      }
    });
  }

  String _createInviteLink(String code) => Uri(
    scheme: 'acici-budget',
    host: 'join',
    queryParameters: {'code': code},
  ).toString();

  Future<void> _importPrivateRecords() async {
    final snapshot = await DatabaseHelper.instance.getLocalSnapshot();
    final count = snapshot.values.fold<int>(
      0,
      (total, records) => total + records.length,
    );
    if (count == 0) {
      _showMessage('Bu cihazda aktarılacak kişisel kayıt bulunmuyor.');
      return;
    }
    if (!mounted) return;
    final shouldImport = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kişisel kayıtları aktar'),
        content: Text(
          'Bu cihazdaki $count gelir, gider, taksit ve yatırım kaydı ortak bütçeye kopyalanacak. '
          'Kişisel kayıtlarınız cihazda kalır. Devam edilsin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aktar'),
          ),
        ],
      ),
    );
    if (shouldImport != true || !mounted) return;
    await _perform(() async {
      final imported = await SharedBudgetService.importLocalSnapshot(snapshot);
      _showMessage('$imported kayıt ortak bütçeye aktarıldı.');
    });
  }

  Future<void> _signOut() async {
    await _perform(() async {
      await SharedBudgetService.client!.auth.signOut();
      await _setActiveHousehold(null);
      _inviteCode.clear();
      if (mounted) setState(() {});
      _showMessage('Çıkış yapıldı. Kişisel kayıtlarınız cihazda duruyor.');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!SharedBudgetService.isConfigured) {
      return Scaffold(
        appBar: AppBar(
          leading: widget.onBack == null
              ? null
              : IconButton(
                  tooltip: 'Geri',
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back),
                ),
          title: const Text('Ortak Bütçe'),
        ),
        body: const Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cloud_off, size: 44),
              SizedBox(height: 16),
              Text(
                'Ortak bütçeyi etkinleştirmek için Supabase projesi gerekli.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text(
                'Supabase projesini oluşturup SQL migration dosyasını çalıştırdıktan '
                'sonra uygulamayı proje URL’si ve publishable key ile başlatın. '
                'Bu bilgiler eklenene kadar uygulama yerel veritabanıyla çalışmaya devam eder.',
              ),
              SizedBox(height: 16),
              SelectableText(
                'flutter run --dart-define=SUPABASE_URL=https://proje-id.supabase.co '
                '--dart-define=SUPABASE_ANON_KEY=sb_publishable_…',
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack == null
            ? null
            : IconButton(
                tooltip: 'Geri',
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
              ),
        title: const Text('Ortak Bütçe'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (!_signedIn) ..._buildAuthForm(),
            if (_signedIn) ..._buildSharedBudgetControls(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAuthForm() => [
    const Text(
      'İki kişi aynı gelir ve giderleri görmek için ayrı hesaplarıyla giriş yapar.',
    ),
    const SizedBox(height: 20),
    TextField(
      controller: _email,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(
        labelText: 'E-posta',
        border: OutlineInputBorder(),
      ),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _password,
      obscureText: true,
      decoration: const InputDecoration(
        labelText: 'Şifre (en az 6 karakter)',
        border: OutlineInputBorder(),
      ),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _inviteCode,
      textCapitalization: TextCapitalization.characters,
      decoration: const InputDecoration(
        labelText: 'Davet kodu (ortak bütçeye katılacaksanız)',
        border: OutlineInputBorder(),
      ),
    ),
    const SizedBox(height: 8),
    const Text(
      'Davet koduyla katılmak için önce bu hesapla giriş yapın veya hesap oluşturun.',
      style: TextStyle(fontSize: 12),
    ),
    const SizedBox(height: 12),
    FilledButton(
      onPressed: _busy ? null : _authenticate,
      child: Text(_isRegistering ? 'Hesap Oluştur' : 'Giriş Yap'),
    ),
    TextButton(
      onPressed: _busy
          ? null
          : () => setState(() => _isRegistering = !_isRegistering),
      child: Text(
        _isRegistering
            ? 'Zaten hesabım var, giriş yap'
            : 'Hesabım yok, kayıt ol',
      ),
    ),
  ];

  List<Widget> _buildSharedBudgetControls() => [
    Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(SharedBudgetService.client!.auth.currentUser!.email ?? ''),
        subtitle: Text(
          _householdId == null ? 'Ortak bütçe seçilmedi' : 'Ortak bütçe aktif',
        ),
        trailing: IconButton(
          tooltip: 'Çıkış yap',
          onPressed: _busy ? null : _signOut,
          icon: const Icon(Icons.logout),
        ),
      ),
    ),
    if (_householdId != null && SharedBudgetService.hasActiveSharedBudget) ...[
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ortak bütçe açık',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bu bütçeye eklenen yeni kayıtlar iki kişide görünür.',
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.people_outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bu bütçeyi paylaştığınız hesap',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _otherMembersLoadFailed
                              ? 'Üye bilgisi alınamadı. Supabase SQL Editor’da '
                                    '202610040001_household_member_emails.sql '
                                    'dosyasını çalıştırın.'
                              : _otherMemberEmails.isEmpty
                              ? 'Henüz başka bir hesap katılmadı.'
                              : _otherMemberEmails.join(', '),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _busy || _householdMemberCount >= 2
                    ? null
                    : _refreshInvite,
                icon: Icon(
                  _householdMemberCount >= 2 ? Icons.group : Icons.vpn_key,
                ),
                label: Text(
                  _householdMemberCount >= 2
                      ? 'Ortak bütçe dolu (2/2)'
                      : 'Davet kodu oluştur',
                ),
              ),
              if (_inviteCodeForDisplay != null) ...[
                SelectableText(
                  _inviteCodeForDisplay!,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                if (_inviteLinkForDisplay != null) ...[
                  const SizedBox(height: 8),
                  SelectableText(_inviteLinkForDisplay!),
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: _inviteLinkForDisplay!),
                      );
                      if (mounted) {
                        _showMessage('Davet bağlantısı kopyalandı.');
                      }
                    },
                    icon: const Icon(Icons.link),
                    label: const Text('Davet bağlantısını kopyala'),
                  ),
                ],
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: _inviteCodeForDisplay!),
                    );
                    if (mounted) _showMessage('Davet kodu kopyalandı.');
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Kodu kopyala'),
                ),
              ],
              const Divider(),
              OutlinedButton.icon(
                onPressed: _busy ? null : _importPrivateRecords,
                icon: const Icon(Icons.drive_file_move),
                label: const Text('Kişisel kayıtları ortak bütçeye aktar'),
              ),
              const SizedBox(height: 4),
              const Text(
                'Aktarım yalnızca onayınızla yapılır; kişisel kayıtlar cihazınızda da kalır.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : () => _setActiveHousehold(null),
                child: const Text('Kişisel kayıtları göster'),
              ),
              if (_householdMemberCount < 2) ...[
                const Divider(height: 28),
                const Text(
                  'Başka bir hesaptan gelen davet koduyla katıl',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _inviteCode,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Davet kodu',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _joinHousehold,
                  icon: const Icon(Icons.group_add),
                  label: const Text('Davet koduyla katıl'),
                ),
              ],
            ],
          ),
        ),
      ),
    ] else if (_householdId != null) ...[
      const SizedBox(height: 20),
      const Text('Şu anda bu cihazdaki kişisel kayıtlar görüntüleniyor.'),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: _busy ? null : () => _setActiveHousehold(_householdId),
        icon: const Icon(Icons.groups),
        label: const Text('Ortak bütçeyi kullan'),
      ),
      const SizedBox(height: 20),
      TextField(
        controller: _inviteCode,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: 'Davet kodu',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _busy ? null : _joinHousehold,
        icon: const Icon(Icons.group_add),
        label: const Text('Davet koduyla katıl'),
      ),
    ] else ...[
      const SizedBox(height: 20),
      const Text(
        'Yeni ortak bütçe oluşturun veya diğer kişinin davet kodunu girin.',
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _name,
        decoration: const InputDecoration(
          labelText: 'Ortak bütçe adı',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: _busy ? null : _createHousehold,
        icon: const Icon(Icons.add_home),
        label: const Text('Ortak bütçe oluştur'),
      ),
      const SizedBox(height: 20),
      TextField(
        controller: _inviteCode,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: 'Davet kodu',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _busy ? null : _joinHousehold,
        icon: const Icon(Icons.group_add),
        label: const Text('Davet koduyla katıl'),
      ),
    ],
  ];
}
