import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/connection_manager.dart';
import '../../core/app_version.dart';
import 'connections_sheet.dart';

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
    final cm = context.read<ConnectionManager>();
    if (cm.activeEndpoint == null) {
      await openProfileEditor(context);
      return;
    }
    if (!_form.currentState!.validate()) return;
    await context.read<AuthController>().login(_username.text, _password.text);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cm = context.read<ConnectionManager>();
      // وضعیت آدرس‌ها برای نمایش در کارت اتصال؛ اگر آدرس فعلی قطع بود
      // و آدرس دیگری در دسترس است، همان‌جا سوییچ شود.
      cm.recheck().then((_) => cm.probeAll());
    });
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
                          const SizedBox(height: 22),
                          const _ConnectionCard(),
                          const SizedBox(height: 16),
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
                            onPressed: () => showConnectionsSheet(context),
                            icon: const Icon(Icons.hub_outlined, size: 19),
                            label: const Text('مدیریت سرورها و آدرس‌ها'),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'نسخهٔ ${toFaDigits(appVersion)} • Android و iOS',
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

/// کارت سرور فعال در فرم ورود — لمس برای تعویض سرور یا آدرس
class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard();

  @override
  Widget build(BuildContext context) {
    final cm = context.watch<ConnectionManager>();
    final p = cm.activeProfile;
    final e = cm.activeEndpoint;
    final probe = e == null ? null : cm.probeOf(e.url);
    final empty = p == null || e == null;
    return Material(
      color: empty ? const Color(0xfffff7e6) : const Color(0xfff3f6ff),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => empty
            ? openProfileEditor(context)
            : showConnectionsSheet(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  empty ? Icons.add_link_rounded : endpointIcon(e.label),
                  color: empty ? Colors.orange.shade800 : const Color(0xff2547a8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      empty ? 'سروری تعریف نشده' : p.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      empty
                          ? 'برای تعریف سرور و آدرس‌ها لمس کنید'
                          : '${e.displayLabel}'
                                '${p.endpoints.length > 1 ? '  •  ${toFaDigits(p.endpoints.length)} آدرس' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.blueGrey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              if (probe != null) ProbeBadge(result: probe),
              const SizedBox(width: 4),
              Icon(
                Icons.unfold_more_rounded,
                color: Colors.blueGrey.shade400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
