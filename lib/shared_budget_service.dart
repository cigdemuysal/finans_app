import 'package:supabase_flutter/supabase_flutter.dart';

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

  static Future<List<Map<String, dynamic>>> getRecords(String kind) async {
    final householdId = _requireHousehold();
    final rows = await client!
        .from('financial_records')
        .select('id, data')
        .eq('household_id', householdId)
        .eq('kind', kind)
        .order('created_at', ascending: false);

    return rows.map((row) {
      final data = Map<String, dynamic>.from(row['data'] as Map);
      data['id'] = row['id'] as int;
      return data;
    }).toList();
  }

  static Future<int> insertRecord(
    String kind,
    Map<String, dynamic> data,
  ) async {
    final householdId = _requireHousehold();
    final row = await client!
        .from('financial_records')
        .insert({'household_id': householdId, 'kind': kind, 'data': data})
        .select('id')
        .single();
    return row['id'] as int;
  }

  static Future<int> updateRecord(
    String kind,
    int id,
    Map<String, dynamic> data,
  ) async {
    final householdId = _requireHousehold();
    final rows = await client!
        .from('financial_records')
        .update({'data': data})
        .eq('household_id', householdId)
        .eq('kind', kind)
        .eq('id', id)
        .select('id');
    return rows.length;
  }

  static Future<int> deleteRecord(String kind, int id) async {
    final householdId = _requireHousehold();
    final rows = await client!
        .from('financial_records')
        .delete()
        .eq('household_id', householdId)
        .eq('kind', kind)
        .eq('id', id)
        .select('id');
    return rows.length;
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

  static String _requireHousehold() {
    if (!hasActiveSharedBudget) {
      throw const AuthException('Ortak bütçe oturumu açık değil.');
    }
    return activeHouseholdId!;
  }
}
