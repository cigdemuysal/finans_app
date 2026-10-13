import 'package:flutter/material.dart';

import 'app.dart';
import 'services/crash_reporting.dart';
import 'services/database_helper.dart';
import 'services/shared_budget_service.dart';

Future<void> main() async {
  await CrashReporting.run(_startApp);
}

Future<void> _startApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedBudgetService.initialize();
  SharedBudgetService.activeHouseholdId = await DatabaseHelper.instance
      .getActiveHouseholdId();
  SharedBudgetService.sharedModeEnabled = await DatabaseHelper.instance
      .isSharedModeEnabled();
  runApp(const FinansApp());
}
