import 'dart:ui';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// SHARED SHEET / FORM COMPONENTS
// ─────────────────────────────────────────────────────────────

class AdminFormField {
  final String label;
  final TextEditingController ctrl;
  final String hint;
  final int maxLines;
  const AdminFormField(this.label, this.ctrl, {this.hint = '', this.maxLines = 1});
}

class AdminSearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final ValueChanged<String> onChanged;

  const AdminSearchBar({
    super.key,
    required this.ctrl,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: ctrl,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.3), fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded,
              color: Colors.white.withOpacity(0.3), size: 18),
          suffixIcon: ctrl.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    ctrl.clear();
                    onChanged('');
                  },
                  child: Icon(Icons.close_rounded,
                      color: Colors.white.withOpacity(0.3),
                      size: 16),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

class AdminAddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const AdminAddButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFFF3366), Color(0xFF6C63FF)]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF3366).withOpacity(0.2),
              blurRadius: 12,
              spreadRadius: -4,
            )
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center,
            children: [
          const Icon(Icons.add_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              )),
        ]),
      ),
    );
  }
}

class AdminSheet extends StatelessWidget {
  final String title;
  final Widget child;

  const AdminSheet({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
        border:
            Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Text(title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  )),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.close_rounded,
                    color: Colors.white.withOpacity(0.4),
                    size: 20),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Flexible(child: SingleChildScrollView(child: child)),
        ],
      ),
    );
  }
}

class AdminFormSheet extends StatelessWidget {
  final String title;
  final List<AdminFormField> fields;
  final Widget? extraContent;
  final VoidCallback onSave;

  const AdminFormSheet({
    super.key,
    required this.title,
    required this.fields,
    this.extraContent,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
        border:
            Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  )),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.close_rounded,
                    color: Colors.white.withOpacity(0.4),
                    size: 20),
              ),
            ]),
            const SizedBox(height: 16),
            ...fields.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.label.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          )),
                      const SizedBox(height: 6),
                      TextField(
                        controller: f.ctrl,
                        maxLines: f.maxLines,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: f.hint,
                          hintStyle: TextStyle(
                              color:
                                  Colors.white.withOpacity(0.25),
                              fontSize: 12),
                          filled: true,
                          fillColor:
                              Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: const Color(0xFFFF3366).withOpacity(0.5)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                )),
            if (extraContent != null) ...[
              const SizedBox(height: 8),
              extraContent!,
            ],
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onSave,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFFF3366), Color(0xFF6C63FF)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text('Save Changes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      )),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const AdminSectionHeader({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: Colors.white.withOpacity(0.3), size: 14),
      const SizedBox(width: 7),
      Text(title.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          )),
    ]);
  }
}

class AdminGlassCard extends StatelessWidget {
  final List<Widget> children;
  const AdminGlassCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
              children: children.asMap().entries.map((e) {
            final isLast = e.key == children.length - 1;
            return Column(children: [
              e.value,
              if (!isLast)
                Divider(
                    height: 1,
                    color: Colors.white.withOpacity(0.05),
                    indent: 54),
            ]);
          }).toList()),
        ),
      ),
    );
  }
}

class AdminErrorCard extends StatelessWidget {
  final String message;
  const AdminErrorCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: const Color(0xFFFF4444).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFF4444).withOpacity(0.3))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFFF4444), size: 32),
            const SizedBox(height: 10),
            const Text('Something went wrong',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class AdminLoader extends StatelessWidget {
  const AdminLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(color: Color(0xFFFF3366)));
  }
}
