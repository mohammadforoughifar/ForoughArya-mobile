String platformReadConfigJson() => '{}';

String platformReadEnvironmentJson() => '{}';

Future<String> platformPushActionJson(
  String action,
  String root,
  String token,
  int userId,
  int companyId,
) async => '{"supported":false,"enabled":false,"message":"فقط در نسخهٔ وب/PWA فعال است."}';

void platformSetAppBadge(int count) {}

Future<bool> platformUpdatePwa() async => false;

void platformShowIosInstallBanner() {}
