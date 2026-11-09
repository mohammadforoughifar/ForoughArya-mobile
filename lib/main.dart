import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'core/auth/auth_controller.dart';
import 'core/network/api_client.dart';
import 'features/misc/data/minutes_repository.dart';
import 'features/office_automation/data/email_draft_store.dart';
import 'features/office_automation/data/email_repository.dart';
import 'features/office_automation/data/office_repository.dart';
import 'features/work_orders/data/work_order_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  final api = ApiClient(storage);
  final auth = AuthController(api, storage)..initialize();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        Provider.value(value: api),
        Provider(create: (_) => WorkOrderRepository(api)),
        Provider(create: (_) => OfficeAutomationRepository(api)),
        Provider(create: (_) => EmailRepository(api)),
        Provider(create: (_) => EmailDraftStore(storage)),
        Provider(create: (_) => MinutesRepository(api)),
      ],
      child: const ForoughApp(),
    ),
  );
}
