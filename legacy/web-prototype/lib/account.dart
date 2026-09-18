part of 'main.dart';

class AccountGate extends StatelessWidget {
  const AccountGate({super.key});
  @override
  Widget build(BuildContext context) {
    if (NourishBackend.initializationError != null)
      return Scaffold(
          body: Center(
              child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Text(NourishBackend.initializationError!))));
    if (!NourishBackend.connected) return const Home();
    return StreamBuilder(
        stream: NourishBackend.client!.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final user = NourishBackend.client!.auth.currentUser;
          return user == null
              ? const SignInPage()
              : Home(key: ValueKey(user.id));
        });
  }
}

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final email = TextEditingController(), code = TextEditingController();
  bool busy = false, sent = false;
  String? error;
  @override
  void dispose() {
    email.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.text.trim())) {
      setState(() => error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await NourishBackend.client!.auth.signInWithOtp(
          email: email.text.trim(),
          emailRedirectTo: Uri.base.resolve('/').toString());
      setState(() => sent = true);
    } catch (_) {
      setState(() => error =
          'Could not send your sign-in email. Please try again shortly.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: Center(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Card(
                      child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.spa_rounded,
                                    color: green, size: 42),
                                const SizedBox(height: 24),
                                const Text('Your everyday, together.',
                                    style: TextStyle(
                                        fontSize: 29,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 12),
                                const Text(
                                    'Sign in to keep your meals, workouts and progress in one place.',
                                    style: TextStyle(color: muted)),
                                const SizedBox(height: 28),
                                TextField(
                                    controller: email,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: const InputDecoration(
                                        labelText: 'Email address')),
                                const SizedBox(height: 18),
                                if (sent)
                                  const Padding(
                                      padding: EdgeInsets.only(bottom: 18),
                                      child: Text(
                                          'Check your email for a secure sign-in link. Open it in this browser to continue.',
                                          style: TextStyle(color: green))),
                                if (error != null)
                                  Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 18),
                                      child: Text(error!,
                                          style: const TextStyle(
                                              color: Colors.red))),
                                SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                        onPressed: busy ? null : send,
                                        child: Text(busy
                                            ? 'Sending…'
                                            : sent
                                                ? 'Send another link'
                                                : 'Email me a sign-in link'))),
                              ])))))));
}
