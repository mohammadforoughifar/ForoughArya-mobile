import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'core/auth/auth_controller.dart';
import 'core/network/api_client.dart';
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
      ],
      child: const ForoughApp(),
    ),
  );
}
