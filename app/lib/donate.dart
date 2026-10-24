import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ui.dart';

/// Where donations go. Change these with `tools/make_donate_qr.py`, which draws
/// the QR code bundled in `assets/donate/upi-qr.svg` from the same two values.
const upiId = 'das.arani@pingpay';
const upiName = 'Arani Das';

/// The UPI payment link: an app that handles UPI opens it with the payee filled in
/// (the amount is left to the donor).
final upiLink = Uri.parse(
  'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(upiName)}&cu=INR',
);

/// The "support lexodle" part of the settings: the UPI ID to copy, its QR code
/// to scan, and a button that opens a UPI app. Lexodle is free and has no ads;
/// this is the only way to chip in, and nothing is sent anywhere by the app.
class DonateSection extends StatefulWidget {
  const DonateSection({super.key, this.open});

  /// Opens a link; a test gives its own. The default hands the UPI link to the
  /// phone, which asks which of its UPI apps should take it.
  final Future<bool> Function(Uri link)? open;

  @override
  State<DonateSection> createState() => _DonateSectionState();
}

class _DonateSectionState extends State<DonateSection> {
  String _note = '';

  Future<void> _copy() async {
    await Clipboard.setData(const ClipboardData(text: upiId));
    if (mounted) setState(() => _note = 'copied $upiId');
  }

  Future<void> _pay() async {
    final open = widget.open ?? (u) => launchUrl(u);
    var ok = false;
    try {
      ok = await open(upiLink);
    } catch (_) {}
    if (!ok && mounted) {
      setState(() => _note = 'no UPI app opened. copy the ID or scan the code');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final dim = TextStyle(
      fontSize: 12,
      color: c.onSurface.withValues(alpha: dimAlpha),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'lexodle is free, with no ads. if you enjoy it, you can chip in by UPI.',
          style: dim,
        ),
        const SizedBox(height: 12),
        Center(
          // the code carries its own white ground and quiet border (a QR code is
          // dark on light whatever the theme), so no colour is chosen here
          child: ClipRRect(
            key: const ValueKey('donate-qr'),
            borderRadius: BorderRadius.circular(6),
            child: SvgPicture.asset(
              'assets/donate/upi-qr.svg',
              width: 180,
              height: 180,
              semanticsLabel: 'UPI QR code for $upiId',
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SelectableText(
                upiId,
                key: const ValueKey('donate-id'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              key: const ValueKey('donate-copy'),
              tooltip: 'copy the UPI ID',
              onPressed: _copy,
              icon: const Icon(Icons.copy, size: 18),
            ),
          ],
        ),
        Text(upiName, style: dim),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            key: const ValueKey('donate-pay'),
            onPressed: _pay,
            child: const Text('pay with a UPI app'),
          ),
        ),
        if (_note.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(_note, key: const ValueKey('donate-note'), style: dim),
        ],
      ],
    );
  }
}
