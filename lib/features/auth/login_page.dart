import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/api_client.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    await context.read<AuthController>().login(_username.text, _password.text);
  }

  Future<void> _serverSettings() async {
    final api = context.read<ApiClient>();
    final controller = TextEditingController(text: api.baseUrl);
    final form = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('آدرس سرور'),
        content: Form(
          key: form,
          child: TextFormField(
            controller: controller,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'API Base URL',
              hintText: 'https://example.com',
            ),
            validator: (v) => v == null || v.trim().isEmpty
                ? 'آدرس سرور را وارد کنید.'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              await api.setBaseUrl(controller.text);
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff101d49), Color(0xff2547a8), Color(0xff5136a7)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(26, 32, 26, 24),
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xffe9efff),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.grid_view_rounded,
                              color: Color(0xff2547a8),
                              size: 34,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'ورود به فروغ آریا',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'با حساب سازمانی خود وارد شوید',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.blueGrey.shade500),
                          ),
                          const SizedBox(height: 28),
                          TextFormField(
                            controller: _username,
                            textDirection: TextDirection.ltr,
                            autocorrect: false,
                            enableSuggestions: false,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'نام کاربری',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'نام کاربری را وارد کنید.'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _password,
                            textDirection: TextDirection.ltr,
                            obscureText: !_showPassword,
                            autocorrect: false,
                            enableSuggestions: false,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'رمز عبور',
                              prefixIcon: const Icon(Icons.key_outlined),
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _showPassword = !_showPassword,
                                ),
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                            validator: (v) => v == null || v.isEmpty
                                ? 'رمز عبور را وارد کنید.'
                                : null,
                          ),
                          if (auth.error != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                auth.error!,
                                style: TextStyle(color: Colors.red.shade800),
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          FilledButton.icon(
                            onPressed: auth.busy ? null : _submit,
                            icon: auth.busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.login),
                            label: const Text('ورود'),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _serverSettings,
                            icon: const Icon(Icons.dns_outlined, size: 19),
                            label: const Text('تنظیم آدرس سرور'),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'نسخهٔ موبایل • Android و iOS',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blueGrey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
