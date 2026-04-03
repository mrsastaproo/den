import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/admin_service.dart';
import '../core/admin_core_widgets.dart';

class ContentTab extends ConsumerStatefulWidget {
  const ContentTab({super.key});

  @override
  ConsumerState<ContentTab> createState() => _ContentTabState();
}

class _ContentTabState extends ConsumerState<ContentTab> {
  final _pageCtrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subTabs = ['Banners', 'Sections'];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Row(
            children: subTabs.asMap().entries.map((e) {
              final sel = e.key == _page;
              return GestureDetector(
                onTap: () {
                  setState(() => _page = e.key);
                  _pageCtrl.animateToPage(e.key, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.07)),
                  ),
                  child: Text(e.value, style: TextStyle(color: sel ? Colors.white : Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: PageView(
            controller: _pageCtrl,
            onPageChanged: (p) => setState(() => _page = p),
            children: const [
              _BannersPage(),
              _CuratedSectionsPage(),
            ],
          ),
        ),
      ],
    );
  }
}

class _BannersPage extends ConsumerWidget {
  const _BannersPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminBannersProvider);
    return async.when(
      loading: () => const AdminLoader(),
      error: (e, _) => AdminErrorCard(message: e.toString()),
      data: (banners) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        physics: const BouncingScrollPhysics(),
        children: [
          AdminAddButton(label: 'Add Banner', onTap: () => _showBannerForm(context, ref, null)),
          const SizedBox(height: 10),
          ...banners.map((b) => _BannerTile(
                banner: b,
                onEdit: () => _showBannerForm(context, ref, b),
                onDelete: () async => await ref.read(adminServiceProvider).deleteBanner(b.id),
                onToggle: (v) async => await ref.read(adminServiceProvider).updateBanner(b.id, {'isActive': v}),
              )),
        ],
      ),
    );
  }

  void _showBannerForm(BuildContext context, WidgetRef ref, FeaturedBanner? banner) {
    final titleCtrl = TextEditingController(text: banner?.title ?? '');
    final subtitleCtrl = TextEditingController(text: banner?.subtitle ?? '');
    final imageCtrl = TextEditingController(text: banner?.imageUrl ?? '');
    final queryCtrl = TextEditingController(text: banner?.actionQuery ?? '');
    final orderCtrl = TextEditingController(text: '${banner?.order ?? 0}');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminFormSheet(
        title: banner == null ? 'Add Banner' : 'Edit Banner',
        fields: [
          AdminFormField('Title', titleCtrl, hint: 'e.g. Featured Playlist'),
          AdminFormField('Subtitle', subtitleCtrl, hint: 'e.g. Hand-picked for you'),
          AdminFormField('Image URL', imageCtrl, hint: 'https://...'),
          AdminFormField('Search Query / Action', queryCtrl, hint: 'e.g. top bollywood hits'),
          AdminFormField('Display Order', orderCtrl, hint: '0'),
        ],
        onSave: () async {
          final order = int.tryParse(orderCtrl.text) ?? 0;
          if (banner == null) {
            await ref.read(adminServiceProvider).createBanner(title: titleCtrl.text, subtitle: subtitleCtrl.text, imageUrl: imageCtrl.text, actionQuery: queryCtrl.text, order: order);
          } else {
            await ref.read(adminServiceProvider).updateBanner(banner.id, {'title': titleCtrl.text, 'subtitle': subtitleCtrl.text, 'imageUrl': imageCtrl.text, 'actionQuery': queryCtrl.text, 'order': order});
          }
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }
}

class _BannerTile extends StatelessWidget {
  final FeaturedBanner banner;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const _BannerTile({required this.banner, required this.onEdit, required this.onDelete, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.07))),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (banner.imageUrl.isNotEmpty)
            SizedBox(height: 80, width: double.infinity, child: Image.network(banner.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.white.withOpacity(0.05), child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.white24))))),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(banner.title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                        Text(banner.subtitle, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                      ],
                    ),
                  ),
                  Switch.adaptive(value: banner.isActive, onChanged: onToggle, activeColor: const Color(0xFF11D47B)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text('Order: ${banner.order}', style: const TextStyle(color: Colors.white70, fontSize: 10))),
                  const Spacer(),
                  GestureDetector(onTap: onEdit, child: const Icon(Icons.edit_rounded, color: Color(0xFF6C63FF), size: 18)),
                  const SizedBox(width: 12),
                  GestureDetector(onTap: onDelete, child: const Icon(Icons.delete_rounded, color: Color(0xFFFF4444), size: 18)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CuratedSectionsPage extends ConsumerWidget {
  const _CuratedSectionsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminCuratedProvider);
    return async.when(
      loading: () => const AdminLoader(),
      error: (e, _) => AdminErrorCard(message: e.toString()),
      data: (sections) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        physics: const BouncingScrollPhysics(),
        children: [
          AdminAddButton(label: 'Add Section', onTap: () => _showSectionForm(context, ref, null)),
          const SizedBox(height: 10),
          ...sections.map((s) => _SectionTile(
                section: s,
                onEdit: () => _showSectionForm(context, ref, s),
                onDelete: () async => await ref.read(adminServiceProvider).deleteCuratedSection(s['id']),
                onToggle: (v) async => await ref.read(adminServiceProvider).updateCuratedSection(s['id'], {'isActive': v}),
              )),
        ],
      ),
    );
  }

  void _showSectionForm(BuildContext context, WidgetRef ref, Map<String, dynamic>? section) {
    final titleCtrl = TextEditingController(text: section?['title'] ?? '');
    final subtitleCtrl = TextEditingController(text: section?['subtitle'] ?? '');
    final queryCtrl = TextEditingController(text: section?['query'] ?? '');
    final orderCtrl = TextEditingController(text: '${section?['order'] ?? 99}');
    String style = section?['style'] ?? 'standard';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminFormSheet(
        title: section == null ? 'Add Section' : 'Edit Section',
        fields: [
          AdminFormField('Title', titleCtrl, hint: 'e.g. Trending Now'),
          AdminFormField('Subtitle', subtitleCtrl, hint: 'e.g. what everyone\'s playing'),
          AdminFormField('Search Query', queryCtrl, hint: 'e.g. trending hindi songs 2025'),
          AdminFormField('Display Order', orderCtrl, hint: '99'),
        ],
        extraContent: StatefulBuilder(
          builder: (_, setS) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Card Style', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
              const SizedBox(height: 8),
              Row(
                  children: ['standard', 'wide', 'ranked'].map((s) {
                final sel = s == style;
                return GestureDetector(
                  onTap: () => setS(() => style = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(color: sel ? const Color(0xFFFF3366).withOpacity(0.2) : Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? const Color(0xFFFF3366).withOpacity(0.4) : Colors.white.withOpacity(0.08))),
                    child: Text(s, style: TextStyle(color: sel ? const Color(0xFFFF3366) : Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
                  ),
                );
              }).toList()),
            ],
          ),
        ),
        onSave: () async {
          final order = int.tryParse(orderCtrl.text) ?? 99;
          if (section == null) {
            await ref.read(adminServiceProvider).createCuratedSection(title: titleCtrl.text, subtitle: subtitleCtrl.text, query: queryCtrl.text, style: style, order: order);
          } else {
            await ref.read(adminServiceProvider).updateCuratedSection(section['id'], {'title': titleCtrl.text, 'subtitle': subtitleCtrl.text, 'query': queryCtrl.text, 'style': style, 'order': order});
          }
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  final Map<String, dynamic> section;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const _SectionTile({required this.section, required this.onEdit, required this.onDelete, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isActive = section['isActive'] ?? true;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.07))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(section['title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(section['subtitle'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
                const SizedBox(height: 4),
                Row(children: [
                   Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(section['style'] ?? 'standard', style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 10))),
                  const SizedBox(width: 6),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text('Order: ${section['order'] ?? 0}', style: const TextStyle(color: Colors.white70, fontSize: 10))),
                ]),
              ],
            ),
          ),
          Column(children: [
            Switch.adaptive(value: isActive, onChanged: onToggle, activeColor: const Color(0xFF11D47B)),
            Row(children: [
              GestureDetector(onTap: onEdit, child: Icon(Icons.edit_rounded, color: Colors.white.withOpacity(0.4), size: 16)),
              const SizedBox(width: 12),
              GestureDetector(onTap: onDelete, child: const Icon(Icons.delete_rounded, color: Color(0xFFFF4444), size: 16)),
            ]),
          ]),
        ],
      ),
    );
  }
}
