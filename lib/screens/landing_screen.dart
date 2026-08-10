import 'package:flutter/material.dart';

const _ink = Color(0xFF102A43);
const _navy = Color(0xFF0B1F33);
const _blue = Color(0xFF2563EB);
const _mint = Color(0xFF20B486);
const _cloud = Color(0xFFF5F8FC);

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SelectionArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _Header(onLaunch: () => Navigator.pushNamed(context, '/dashboard')),
              _Hero(onLaunch: () => Navigator.pushNamed(context, '/dashboard')),
              const _TrustStrip(),
              const _Workflow(),
              const _ValidationSection(),
              _FinalCta(onLaunch: () => Navigator.pushNamed(context, '/dashboard')),
              const _Footer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageWidth extends StatelessWidget {
  const _PageWidth({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: child,
          ),
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.onLaunch});
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 560;
    return _PageWidth(
      child: SizedBox(
        height: 88,
        child: Row(
          children: [
            Image.asset('assets/images/enricherpro_logo_large.png', height: 48),
            const Spacer(),
            if (MediaQuery.sizeOf(context).width > 760) ...[
              const _NavLink('How it works'),
              const _NavLink('Validation'),
              const _NavLink('Security'),
              const SizedBox(width: 16),
            ],
            if (!compact) ...[
              OutlinedButton(onPressed: onLaunch, child: const Text('Sign in')),
              const SizedBox(width: 10),
            ],
            FilledButton(
              onPressed: onLaunch,
              child: Text(compact ? 'Open' : 'Open workspace'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: () {},
        child: Text(label, style: const TextStyle(color: _ink)),
      );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onLaunch});
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 880;
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Eyebrow('B2B CONTACT INTELLIGENCE'),
        const SizedBox(height: 22),
        Text(
          'Turn a contact list into a pipeline you can trust.',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: _navy,
                fontWeight: FontWeight.w800,
                height: 1.02,
                letterSpacing: -2,
              ),
        ),
        const SizedBox(height: 24),
        Text(
          'EnricherPro finds professional emails, validates deliverability, and keeps the evidence behind every result—before your team hits send.',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color(0xFF52677D),
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
        ),
        const SizedBox(height: 34),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: onLaunch,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Enrich your first list'),
            ),
            OutlinedButton.icon(
              onPressed: onLaunch,
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Explore the workspace'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'CSV in • Verified data out • No credit card required',
          style: TextStyle(color: Color(0xFF6B7F93), fontWeight: FontWeight.w600),
        ),
      ],
    );
    const visual = _ProductPreview();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF8FBFF), Color(0xFFEFF7F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 76),
      child: _PageWidth(
        child: narrow
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [copy, const SizedBox(height: 48), visual])
            : Row(children: [Expanded(child: copy), const SizedBox(width: 64), const Expanded(child: visual)]),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(color: _blue, fontWeight: FontWeight.w800, letterSpacing: 1.5),
      );
}

class _ProductPreview extends StatelessWidget {
  const _ProductPreview();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFDDE7F0)),
          boxShadow: const [BoxShadow(color: Color(0x1A183B56), blurRadius: 40, offset: Offset(0, 18))],
        ),
        child: Column(
          children: [
            Row(children: [
              const CircleAvatar(radius: 20, backgroundColor: Color(0xFFE8F0FF), child: Icon(Icons.person_outline, color: _blue)),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Maya Laurent', style: TextStyle(fontWeight: FontWeight.w800, color: _ink)),
                Text('VP, Revenue Operations', style: TextStyle(color: Color(0xFF6B7F93))),
              ])),
              _status('VERIFIED', _mint),
            ]),
            const SizedBox(height: 22),
            _resultRow(Icons.alternate_email, 'maya.laurent@northstar.io', 'Mailbox confirmed'),
            _resultRow(Icons.dns_outlined, 'northstar.io', 'MX records active'),
            _resultRow(Icons.shield_outlined, 'Deliverability score', '96 / 100'),
            const SizedBox(height: 14),
            const LinearProgressIndicator(value: .96, minHeight: 8, borderRadius: BorderRadius.all(Radius.circular(8))),
          ],
        ),
      );
}

Widget _resultRow(IconData icon, String title, String detail) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Icon(icon, size: 20, color: _blue),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: const TextStyle(color: _ink, fontWeight: FontWeight.w600))),
        Text(detail, style: const TextStyle(color: Color(0xFF6B7F93), fontSize: 12)),
      ]),
    );

Widget _status(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
    );

class _TrustStrip extends StatelessWidget {
  const _TrustStrip();
  @override
  Widget build(BuildContext context) => Container(
        color: _navy,
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: const _PageWidth(
          child: Wrap(
            alignment: WrapAlignment.spaceAround,
            spacing: 32,
            runSpacing: 18,
            children: [
              _TrustItem(Icons.fact_check_outlined, 'Evidence with every result'),
              _TrustItem(Icons.upload_file_outlined, 'CSV-ready workflow'),
              _TrustItem(Icons.security_outlined, 'Conservative validation'),
              _TrustItem(Icons.speed_outlined, 'Built for batch processing'),
            ],
          ),
        ),
      );
}

class _TrustItem extends StatelessWidget {
  const _TrustItem(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: const Color(0xFF65D6B5), size: 20),
        const SizedBox(width: 9),
        Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ]);
}

class _Workflow extends StatelessWidget {
  const _Workflow();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 104),
        child: _PageWidth(
          child: Column(children: [
            const _Eyebrow('A CLEARER WORKFLOW'),
            const SizedBox(height: 14),
            Text('From raw rows to ready-to-contact leads', textAlign: TextAlign.center, style: Theme.of(context).textTheme.displaySmall?.copyWith(color: _navy, fontWeight: FontWeight.w800)),
            const SizedBox(height: 48),
            const Wrap(spacing: 20, runSpacing: 20, children: [
              _StepCard('01', Icons.upload_file_outlined, 'Import', 'Upload a CSV. Smart field mapping keeps your source columns intact.'),
              _StepCard('02', Icons.auto_awesome_outlined, 'Enrich', 'Discover likely business emails using company and person signals.'),
              _StepCard('03', Icons.verified_outlined, 'Validate', 'Review syntax, mail routing, server response, and catch-all risk.'),
            ]),
          ]),
        ),
      );
}

class _StepCard extends StatelessWidget {
  const _StepCard(this.number, this.icon, this.title, this.body);
  final String number;
  final IconData icon;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Container(
        width: 360,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: _cloud, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Icon(icon, color: _blue, size: 30),
            Text(number, style: const TextStyle(color: Color(0xFFBBC9D6), fontSize: 28, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 28),
          Text(title, style: const TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(body, style: const TextStyle(color: Color(0xFF60758A), height: 1.55)),
        ]),
      );
}

class _ValidationSection extends StatelessWidget {
  const _ValidationSection();
  @override
  Widget build(BuildContext context) => Container(
        color: _cloud,
        padding: const EdgeInsets.symmetric(vertical: 96),
        child: _PageWidth(
          child: LayoutBuilder(builder: (context, constraints) {
            const copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Eyebrow('VALIDATION WITH NUANCE'),
              SizedBox(height: 16),
              Text('“Unknown” is better than a false promise.', style: TextStyle(color: _navy, fontSize: 38, height: 1.12, fontWeight: FontWeight.w800)),
              SizedBox(height: 18),
              Text('Mail servers often hide mailbox status. EnricherPro separates confirmed, risky, invalid, and inconclusive results—so your team can make the right call.', style: TextStyle(color: Color(0xFF60758A), fontSize: 18, height: 1.55)),
            ]);
            const checks = Column(children: [
              _Check('Syntax and domain structure', 'Instant'),
              _Check('DNS and prioritized MX routing', 'Verified'),
              _Check('Mailbox server response', 'Conservative'),
              _Check('Catch-all and role-account risk', 'Flagged'),
            ]);
            return constraints.maxWidth < 800
                ? const Column(children: [copy, SizedBox(height: 40), checks])
                : const Row(children: [Expanded(child: copy), SizedBox(width: 70), Expanded(child: checks)]);
          }),
        ),
      );
}

class _Check extends StatelessWidget {
  const _Check(this.title, this.tag);
  final String title;
  final String tag;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFDCE6EF))),
        child: Row(children: [
          const Icon(Icons.check_circle, color: _mint),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(color: _ink, fontWeight: FontWeight.w700))),
          _status(tag.toUpperCase(), _blue),
        ]),
      );
}

class _FinalCta extends StatelessWidget {
  const _FinalCta({required this.onLaunch});
  final VoidCallback onLaunch;
  @override
  Widget build(BuildContext context) => Container(
        color: _blue,
        padding: const EdgeInsets.symmetric(vertical: 76),
        child: _PageWidth(
          child: Column(children: [
            const Text('Put better data behind every outreach.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            const Text('Upload a contact list and see what EnricherPro can verify.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFDCE8FF), fontSize: 18)),
            const SizedBox(height: 28),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _blue),
              onPressed: onLaunch,
              child: const Text('Open EnricherPro'),
            ),
          ]),
        ),
      );
}

class _Footer extends StatelessWidget {
  const _Footer();
  @override
  Widget build(BuildContext context) => const _PageWidth(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 34),
          child: Row(children: [
            Text('© 2026 EnricherPro', style: TextStyle(color: Color(0xFF60758A))),
            Spacer(),
            Text('Built for responsible B2B outreach', style: TextStyle(color: Color(0xFF60758A))),
          ]),
        ),
      );
}
