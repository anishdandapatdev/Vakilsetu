import 'package:flutter/material.dart';

import 'legal_icon.dart';
export 'legal_icon.dart';

const navy = Color(0xFF1D3557),
    teal = Color(0xFF2A9D8F),
    slateBlue = Color(0xFF457B9D),
    bronze = Color(0xFFF5B942);
const ink = Color(0xFF102A56),
    muted = Color(0xFF64748B),
    line = Color(0xFFE1ECF3),
    canvas = Color(0xFFF5FBFC);
const paleTeal = Color(0xFFEAF8F7),
    paleBlue = Color(0xFFF0F8FC),
    paleBronze = Color(0xFFFFF8E8);
TextStyle heading(double size) => TextStyle(
  fontFamily: 'Manrope',
  fontSize: size,
  fontWeight: FontWeight.w800,
  color: ink,
  height: 1.25,
);
ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'Inter',
  scaffoldBackgroundColor: canvas,
  colorScheme: ColorScheme.fromSeed(
    seedColor: navy,
    primary: navy,
    secondary: teal,
    surface: Colors.white,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 13, color: ink, height: 1.5),
    bodySmall: TextStyle(fontSize: 11, color: muted, height: 1.4),
  ),
  dividerTheme: const DividerThemeData(color: line, space: 1),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    hintStyle: const TextStyle(fontSize: 13, color: muted),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: line),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: navy,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: teal,
      side: const BorderSide(color: teal),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
    ),
  ),
  chipTheme: ChipThemeData(
    side: const BorderSide(color: line),
    backgroundColor: Colors.white,
    selectedColor: paleTeal,
    labelStyle: const TextStyle(fontSize: 12),
  ),
  listTileTheme: const ListTileThemeData(
    contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 7),
  ),
);

class Brand extends StatelessWidget {
  final bool small;
  const Brand({super.key, this.small = false});
  @override
  Widget build(BuildContext context) => VakilSetuLogo(height: small ? 39 : 47);
}

class VakilSetuLogo extends StatelessWidget {
  final double height;
  const VakilSetuLogo({super.key, this.height = 44});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'VakilSetu · Advocates Connected',
    image: true,
    child: SizedBox(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/brand/vakilsetu_mark.png',
            height: height,
            width: height * 1.5,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          SizedBox(width: height * .08),
          Image.asset(
            'assets/images/brand/vakilsetu_wordmark.png',
            height: height * .78,
            width: height * 2.35,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ],
      ),
    ),
  );
}

class IllustratedIcon extends StatelessWidget {
  final String name;
  final double size;
  const IllustratedIcon(this.name, {super.key, this.size = 44});

  static const _assets = {
    'home': 'assets/images/navigation/home.png',
    'chats': 'assets/images/navigation/chats.png',
    'advocates': 'assets/images/navigation/advocates.png',
    'courts': 'assets/images/navigation/courts.png',
    'groups': 'assets/images/navigation/groups.png',
    'documents': 'assets/images/navigation/documents.png',
  };

  @override
  Widget build(BuildContext context) {
    final asset = _assets[name];
    if (asset == null) return LegalIcon(name, size: size);
    return Semantics(
      label: '$name illustration',
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          cacheWidth: (size * MediaQuery.devicePixelRatioOf(context) * 2)
              .round(),
          errorBuilder: (_, _, _) => LegalIcon(name, size: size),
        ),
      ),
    );
  }
}

class BrandedSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String icon;
  final String initials;
  final Widget? action;

  const BrandedSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.initials,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const VakilSetuLogo(height: 42),
          const Spacer(),
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Avatar(initials, size: 44),
              Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: teal,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFE2F5FC),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: IllustratedIcon(icon, size: 43),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: heading(21)),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: slateBlue, fontSize: 12),
                ),
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 8), action!],
        ],
      ),
    ],
  );
}

class BrandedTopBar extends StatelessWidget {
  final String initials;
  const BrandedTopBar({super.key, required this.initials});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const VakilSetuLogo(height: 42),
      const Spacer(),
      Stack(
        alignment: Alignment.bottomRight,
        children: [
          Avatar(initials, size: 42),
          Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: teal,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ],
      ),
    ],
  );
}

class UniversalSearchCard extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final Widget? trailing;
  final String? initialValue;
  final ValueChanged<String>? onSubmitted;

  const UniversalSearchCard({
    super.key,
    required this.hint,
    required this.onChanged,
    this.trailing,
    this.initialValue,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Opacity(
              opacity: .055,
              child: Image.asset(
                'assets/images/chat/legal_chat_background.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: const Color(0xFFD8E9F3)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x100C6F91),
                  blurRadius: 14,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: TextFormField(
              initialValue: initialValue,
              onChanged: onChanged,
              onFieldSubmitted: onSubmitted,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: slateBlue, fontSize: 13),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: navy,
                  size: 22,
                ),
                suffixIcon: trailing == null
                    ? null
                    : Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(color: Color(0xFFE4EEF4)),
                          ),
                        ),
                        child: trailing,
                      ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class CompactSearchBox extends UniversalSearchCard {
  const CompactSearchBox({
    super.key,
    required super.hint,
    required super.onChanged,
    super.trailing,
    super.initialValue,
    super.onSubmitted,
  });
}

class StickyBrandSearchHeader extends SliverPersistentHeaderDelegate {
  final String initials;
  final Widget search;
  const StickyBrandSearchHeader({required this.initials, required this.search});

  @override
  double get minExtent => 124;
  @override
  double get maxExtent => 124;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Container(
    color: canvas,
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    child: Column(
      children: [
        BrandedTopBar(initials: initials),
        const SizedBox(height: 10),
        search,
      ],
    ),
  );

  @override
  bool shouldRebuild(covariant StickyBrandSearchHeader oldDelegate) =>
      oldDelegate.initials != initials || oldDelegate.search != search;
}

class Surface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color = Colors.white,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: line),
    ),
    child: child,
  );
}

class Tag extends StatelessWidget {
  final String text;
  final Color color;
  const Tag(this.text, {super.key, this.color = teal});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
    ),
  );
}

class Avatar extends StatelessWidget {
  final String initials;
  final bool group;
  final double size;
  const Avatar(this.initials, {super.key, this.group = false, this.size = 44});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: group ? paleBronze : paleBlue,
      shape: BoxShape.circle,
      border: Border.all(color: line),
    ),
    alignment: Alignment.center,
    child: group
        ? IllustratedIcon('groups', size: size * .78)
        : Text(
            initials,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w700,
              fontSize: size * .3,
              color: slateBlue,
            ),
          ),
  );
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onTap;
  const SectionTitle(this.title, {super.key, this.action, this.onTap});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(title, style: heading(16))),
      if (action != null)
        TextButton(
          onPressed: onTap,
          child: Text(action!, style: const TextStyle(fontSize: 12)),
        ),
    ],
  );
}

class PageTitle extends StatelessWidget {
  final String title, subtitle;
  final Widget? action;
  const PageTitle(this.title, this.subtitle, {super.key, this.action});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 20,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: heading(26)),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: muted, fontSize: 13)),
          ],
        ),
        if (action != null) action!,
      ],
    ),
  );
}

class PageBody extends StatelessWidget {
  final List<Widget> children;
  const PageBody({super.key, required this.children});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 700 ? 18 : 30),
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1300),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  );
}

class SearchBox extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const SearchBox({super.key, required this.hint, required this.onChanged});
  @override
  Widget build(BuildContext context) => TextField(
    onChanged: onChanged,
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search, size: 20, color: muted),
    ),
  );
}

class EmptyState extends StatelessWidget {
  final String title, detail;
  const EmptyState(this.title, this.detail, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(36),
    child: Column(
      children: [
        const LegalIcon('chats', size: 44),
        const SizedBox(height: 16),
        Text(title, style: heading(17)),
        const SizedBox(height: 8),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted),
        ),
      ],
    ),
  );
}

void toast(BuildContext context, String text) => ScaffoldMessenger.of(context)
    .showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
Future<void> info(BuildContext context, String title, String message) =>
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Close'),
          ),
        ],
      ),
    );
