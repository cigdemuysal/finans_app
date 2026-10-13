import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'crash_reporting.dart';
import 'database_helper.dart';

/// Supabase backend for optional shared household budgets.
///
/// When no project keys are supplied, the app continues using its local SQLite
/// database. Configure the project with SUPABASE_URL and SUPABASE_ANON_KEY
/// dart-defines to enable sign-in and shared records.
class SharedBudgetService {
  SharedBudgetService._();

  static const String authRedirectUrl = 'acici-budget://auth-callback';

  static const String _url = String.fromEnvironment('SUPABASE_URL');
  static const String _publishableKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static bool get isConfigured => _url.isNotEmpty && _publishableKey.isNotEmpty;

  static SupabaseClient? get client =>
      isConfigured ? Supabase.instance.client : null;

  static String? activeHouseholdId;
  static RealtimeChannel? _recordsChannel;
  static String? _subscribedHouseholdId;
  static bool sharedModeEnabled = false;

  static bool get hasActiveSharedBudget =>
      sharedModeEnabled &&
      client?.auth.currentUser != null &&
      activeHouseholdId != null;

  static Future<void> initialize() async {
    if (!isConfigured) return;
    await Supabase.initialize(url: _url, publishableKey: _publishableKey);
  }

  // ==========================================================
  // ÇEVRİMDIŞI ÇALIŞMA
  // ==========================================================
  //
  // İnternet yokken ortak bütçenin son görülen hâli telefondaki kopyadan
  // gösterilir. Yeni, değişen veya silinen kayıtlar telefonda sıraya alınır ve
  // bağlantı gelince sunucuya gönderilir.

  static const _remoteTimeout = Duration(seconds: 10);

  /// Son sunucu isteği internet olmadığı için başarısız olduysa true.
  static bool isOffline = false;

  /// Sunucuya henüz gönderilmemiş değişiklik sayısı.
  static int pendingChangeCount = 0;

  /// Sunucunun kabul etmediği için gönderilemeyen değişiklik sayısı.
  /// Arayüz bunu bir kez gösterip sıfırlar.
  static int rejectedChangeCount = 0;

  static Future<void>? _syncInProgress;
  static int _lastTempId = 0;
  static final Map<int, int> _sentTempIds = {};

  /// Hatanın internet bağlantısından kaynaklanıp kaynaklanmadığını söyler.
  /// Sunucunun bilerek reddettiği istekler (yetki, geçersiz veri) internet
  /// hatası sayılmaz.
  static bool isNetworkError(Object error) {
    if (error is AuthRetryableFetchException) return true;
    if (error is PostgrestException || error is AuthException) return false;
    if (error is SocketException ||
        error is TimeoutException ||
        error is HandshakeException) {
      return true;
    }
    final text = error.toString();
    return text.contains('SocketException') ||
        text.contains('ClientException') ||
        text.contains('Failed host lookup') ||
        text.contains('Connection closed') ||
        text.contains('Connection refused') ||
        text.contains('Connection reset') ||
        text.contains('Network is unreachable');
  }

  static int _nextTempId() {
    var id = -DateTime.now().microsecondsSinceEpoch;
    if (id >= _lastTempId) id = _lastTempId - 1;
    _lastTempId = id;
    return id;
  }

  static String _newClientRef() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static int _resolveId(int id) => _sentTempIds[id] ?? id;

  static Future<void> _refreshPendingCount(String householdId) async {
    pendingChangeCount = await DatabaseHelper.instance.countPendingOps(
      householdId,
    );
  }

  /// Sıradaki değişiklikleri sunucuya gönderir. İnternet yoksa sessizce durur
  /// ve değişiklikler sırada kalır.
  static Future<void> syncPendingChanges() {
    return _syncInProgress ??= _syncPendingChanges().whenComplete(
      () => _syncInProgress = null,
    );
  }

  static Future<void> _syncPendingChanges() async {
    if (!hasActiveSharedBudget) return;
    final householdId = activeHouseholdId!;
    final ops = await DatabaseHelper.instance.getPendingOps(householdId);
    for (final op in ops) {
      try {
        switch (op.op) {
          case 'insert':
            final id = await _insertRemote(
              householdId,
              op.kind,
              op.data ?? const {},
              op.clientRef ?? _newClientRef(),
            );
            _sentTempIds[op.recordId] = id;
          case 'update':
            await _updateRemote(householdId, op.kind, op.recordId, op.data!);
          case 'delete':
            await _deleteRemote(householdId, op.kind, op.recordId);
        }
        await DatabaseHelper.instance.deletePendingOp(op.seq!);
        isOffline = false;
      } catch (error, stackTrace) {
        if (isNetworkError(error)) {
          isOffline = true;
          break;
        }
        CrashReporting.report(error, stackTrace);
        // Sunucu bu değişikliği kabul etmedi (ör. kayıt diğer kişi
        // tarafından silinmiş). Tekrar denemek sonucu değiştirmez; sıranın
        // tıkanmaması için değişiklik çıkarılır.
        await DatabaseHelper.instance.deletePendingOp(op.seq!);
        rejectedChangeCount++;
      }
    }
    await _refreshPendingCount(householdId);
  }

  static Future<int> _insertRemote(
    String householdId,
    String kind,
    Map<String, dynamic> data,
    String clientRef,
  ) async {
    // Önceki bir deneme sunucuya ulaşıp cevabı alamadan kopmuş olabilir.
    // Aynı anahtarla eklenmiş kayıt varsa tekrar eklenmez.
    final existing = await client!
        .from('financial_records')
        .select('id')
        .eq('household_id', householdId)
        .eq('kind', kind)
        .eq('data->>_client_ref', clientRef)
        .limit(1)
        .timeout(_remoteTimeout);
    if (existing.isNotEmpty) return existing.first['id'] as int;

    final row = await client!
        .from('financial_records')
        .insert({
          'household_id': householdId,
          'kind': kind,
          'data': {...data, '_client_ref': clientRef},
        })
        .select('id')
        .single()
        .timeout(_remoteTimeout);
    return row['id'] as int;
  }

  static Future<int> _updateRemote(
    String householdId,
    String kind,
    int id,
    Map<String, dynamic> data,
  ) async {
    final rows = await client!
        .from('financial_records')
        .update({'data': data})
        .eq('household_id', householdId)
        .eq('kind', kind)
        .eq('id', id)
        .select('id')
        .timeout(_remoteTimeout);
    return rows.length;
  }

  static Future<int> _deleteRemote(
    String householdId,
    String kind,
    int id,
  ) async {
    final rows = await client!
        .from('financial_records')
        .delete()
        .eq('household_id', householdId)
        .eq('kind', kind)
        .eq('id', id)
        .select('id')
        .timeout(_remoteTimeout);
    return rows.length;
  }

  // ==========================================================
  // KAYITLAR
  // ==========================================================

  static Future<List<Map<String, dynamic>>> getRecords(String kind) async {
    final householdId = _requireHousehold();
    await syncPendingChanges();

    List<Map<String, dynamic>> records;
    try {
      final rows = await client!
          .from('financial_records')
          .select('id, data')
          .eq('household_id', householdId)
          .eq('kind', kind)
          .order('created_at', ascending: false)
          .timeout(_remoteTimeout);

      records = rows.map((row) {
        final data = Map<String, dynamic>.from(row['data'] as Map)
          ..remove('_client_ref');
        data['id'] = row['id'] as int;
        return data;
      }).toList();
      isOffline = false;
      await DatabaseHelper.instance.replaceSharedCache(
        householdId,
        kind,
        records,
      );
    } catch (error) {
      if (!isNetworkError(error)) rethrow;
      isOffline = true;
      records = await DatabaseHelper.instance.getSharedCache(householdId, kind);
    }

    final pending = await DatabaseHelper.instance.getPendingOps(
      householdId,
      kind: kind,
    );
    await _refreshPendingCount(householdId);
    return applyPendingOps(records, pending);
  }

  static Future<int> insertRecord(
    String kind,
    Map<String, dynamic> data,
  ) async {
    final householdId = _requireHousehold();
    final clientRef = _newClientRef();
    await syncPendingChanges();
    if (pendingChangeCount == 0) {
      try {
        return await _insertRemote(householdId, kind, data, clientRef);
      } catch (error) {
        if (!isNetworkError(error)) rethrow;
        isOffline = true;
      }
    }

    final tempId = _nextTempId();
    await DatabaseHelper.instance.addPendingOp(
      PendingSharedOp(
        householdId: householdId,
        kind: kind,
        op: 'insert',
        recordId: tempId,
        data: data,
        clientRef: clientRef,
      ),
    );
    await _refreshPendingCount(householdId);
    return tempId;
  }

  static Future<int> updateRecord(
    String kind,
    int id,
    Map<String, dynamic> data,
  ) async {
    final householdId = _requireHousehold();
    id = _resolveId(id);
    if (id < 0) {
      // Kayıt henüz sunucuya gitmedi; sıradaki hâli güncellenir.
      final updated = await DatabaseHelper.instance.updatePendingInsert(
        householdId,
        kind,
        id,
        data,
      );
      return updated ? 1 : 0;
    }

    await syncPendingChanges();
    if (pendingChangeCount == 0) {
      try {
        return await _updateRemote(householdId, kind, id, data);
      } catch (error) {
        if (!isNetworkError(error)) rethrow;
        isOffline = true;
      }
    }

    await DatabaseHelper.instance.addPendingOp(
      PendingSharedOp(
        householdId: householdId,
        kind: kind,
        op: 'update',
        recordId: id,
        data: data,
      ),
    );
    await _refreshPendingCount(householdId);
    return 1;
  }

  static Future<int> deleteRecord(String kind, int id) async {
    final householdId = _requireHousehold();
    id = _resolveId(id);
    if (id < 0) {
      // Kayıt henüz sunucuya gitmedi; sıradan çıkarmak yeterli.
      final removed = await DatabaseHelper.instance.deletePendingOpsForRecord(
        householdId,
        kind,
        id,
      );
      await _refreshPendingCount(householdId);
      return removed > 0 ? 1 : 0;
    }

    await syncPendingChanges();
    if (pendingChangeCount == 0) {
      try {
        return await _deleteRemote(householdId, kind, id);
      } catch (error) {
        if (!isNetworkError(error)) rethrow;
        isOffline = true;
      }
    }

    await DatabaseHelper.instance.addPendingOp(
      PendingSharedOp(
        householdId: householdId,
        kind: kind,
        op: 'delete',
        recordId: id,
      ),
    );
    await _refreshPendingCount(householdId);
    return 1;
  }

  static Future<void> updateRealtimeSubscription(
    void Function() onRecordsChanged,
  ) async {
    final householdId = hasActiveSharedBudget ? activeHouseholdId : null;
    if (householdId == _subscribedHouseholdId) return;

    final oldChannel = _recordsChannel;
    _recordsChannel = null;
    _subscribedHouseholdId = null;
    if (oldChannel != null && client != null) {
      await client!.removeChannel(oldChannel);
    }
    if (householdId == null) return;

    _subscribedHouseholdId = householdId;
    _recordsChannel = client!
        .channel('shared-budget-$householdId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'financial_records',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'household_id',
            value: householdId,
          ),
          callback: (_) => onRecordsChanged(),
        )
        .subscribe();
  }

  static Future<String> createHousehold(String name) async {
    final result = await client!.rpc(
      'create_household',
      params: {'household_name': name.trim()},
    );
    return result as String;
  }

  static Future<String> createInvite(String householdId) async {
    final result = await client!.rpc(
      'create_household_invite',
      params: {'target_household_id': householdId},
    );
    return result as String;
  }

  static Future<String> joinHousehold(String inviteCode) async {
    final result = await client!.rpc(
      'join_household',
      params: {'invite_code': inviteCode.trim()},
    );
    return result as String;
  }

  static Future<List<String>> getOtherHouseholdMemberEmails(
    String householdId,
  ) async {
    final rows = await client!.rpc(
      'get_other_household_members',
      params: {'target_household_id': householdId},
    );
    return (rows as List)
        .map((row) => (row['member_email'] as String?)?.trim() ?? '')
        .where((email) => email.isNotEmpty)
        .toList();
  }

  static Future<int> getHouseholdMemberCount(String householdId) async {
    final rows = await client!
        .from('household_members')
        .select('user_id')
        .eq('household_id', householdId);
    return rows.length;
  }

  static Future<String?> getCurrentUserHouseholdId() async {
    if (client?.auth.currentUser == null) return null;
    final rows = await client!
        .from('household_members')
        .select('household_id')
        .order('joined_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return rows.first['household_id'] as String?;
  }

  static Future<int> importLocalSnapshot(
    Map<String, List<Map<String, dynamic>>> snapshot,
  ) async {
    final householdId = _requireHousehold();
    var imported = 0;
    for (final entry in snapshot.entries) {
      final rows = entry.value
          .where((row) => row['id'] is int)
          .map(
            (row) => {
              'household_id': householdId,
              'kind': entry.key,
              'data': Map<String, dynamic>.from(row)..remove('id'),
              'source_local_id': row['id'],
            },
          )
          .toList();
      if (rows.isEmpty) continue;
      final result = await client!
          .from('financial_records')
          .upsert(
            rows,
            onConflict: 'household_id,created_by,kind,source_local_id',
            ignoreDuplicates: true,
          )
          .select('id');
      imported += result.length;
    }
    return imported;
  }

  /// Kullanıcının hesabını ve sunucudaki verilerini kalıcı olarak siler.
  /// Ortak bütçede başka üye varsa bütçe onda kalır (bkz.
  /// supabase/migrations/202610120001_delete_own_account.sql).
  static Future<void> deleteOwnAccount() async {
    await client!.rpc('delete_own_account');
    try {
      await client!.auth.signOut();
    } catch (_) {
      // Hesap silindiği için oturum sunucuda zaten geçersiz.
    }
    await DatabaseHelper.instance.clearSharedLocalData();
    await DatabaseHelper.instance.setActiveHouseholdId(null);
    await DatabaseHelper.instance.setSharedModeEnabled(false);
    activeHouseholdId = null;
    sharedModeEnabled = false;
    pendingChangeCount = 0;
    isOffline = false;
    _sentTempIds.clear();
  }

  static String _requireHousehold() {
    if (!hasActiveSharedBudget) {
      throw const AuthException('Ortak bütçe oturumu açık değil.');
    }
    return activeHouseholdId!;
  }
}
