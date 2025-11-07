import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/driver_service.dart';

class LinkProfileScreen extends StatefulWidget {
  final VoidCallback onLinked;
  const LinkProfileScreen({super.key, required this.onLinked});

  @override
  State<LinkProfileScreen> createState() => _LinkProfileScreenState();
}

class _LinkProfileScreenState extends State<LinkProfileScreen> {
  final _svc = DriverService();
  final _user = FirebaseAuth.instance.currentUser;
  String phone = '';
  String code = '';
  bool loading = false;
  String info = '';

  Future<void> link() async {
    if (_user == null) return;
    setState(() { loading = true; info = ''; });
    final ok = await _svc.linkByPhoneOrCode(_user!, phone: phone.isNotEmpty ? phone : null, driverCode: code.isNotEmpty ? code : null);
    setState(() { loading = false; info = ok ? 'Linked!' : 'Not found.'; });
    if (ok) widget.onLinked();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 8),
              Text('Link Driver Profile', style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary, fontSize: 20)),
              const SizedBox(height: 8),
              const Text('Enter your phone (as saved by admin) or your driver code.'),
              const SizedBox(height: 12),
              TextField(decoration: const InputDecoration(labelText: 'Phone (+91...)'), onChanged: (v) => phone = v),
              const SizedBox(height: 6),
              const Text('or'),
              const SizedBox(height: 6),
              TextField(decoration: const InputDecoration(labelText: 'Driver Code (e.g., DRV-1023)'), onChanged: (v) => code = v),
              const SizedBox(height: 12),
              FilledButton(onPressed: loading ? null : link, child: Text(loading ? 'Linking…' : 'Link')),
              const SizedBox(height: 8),
              Text(info),
            ]),
          ),
        ),
      ),
    );
  }
}
