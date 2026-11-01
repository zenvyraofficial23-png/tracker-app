import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const TrackerApp());

const _bg = Color(0xFF0E1116);
const _card = Color(0xFF181C24);
const _accent = Color(0xFF2EE6A6);
const _accent2 = Color(0xFF7C5CFF);
const _muted = Color(0xFF8A93A6);

class TrackerApp extends StatelessWidget {
  const TrackerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Tracker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: _bg,
          colorScheme: const ColorScheme.dark(primary: _accent, secondary: _accent2),
          useMaterial3: true,
          fontFamily: 'sans-serif',
        ),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> tasks = [];
  List<Map<String, dynamic>> expenses = [];
  int tab = 0;
  late final AnimationController _fade;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..forward();
    _load();
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      tasks = List<Map<String, dynamic>>.from(jsonDecode(p.getString('tasks') ?? '[]'));
      expenses = List<Map<String, dynamic>>.from(jsonDecode(p.getString('expenses') ?? '[]'));
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('tasks', jsonEncode(tasks));
    await p.setString('expenses', jsonEncode(expenses));
  }

  void _switchTab(int i) {
    HapticFeedback.selectionClick();
    setState(() => tab = i);
    _fade
      ..reset()
      ..forward();
  }

  Future<void> _addItem() async {
    final isExpense = tab == 1;
    final c = TextEditingController();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 4,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: _muted, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Text(isExpense ? 'Naya kharcha' : 'Naya task',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: c,
              autofocus: true,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: isExpense ? 'Amount pehle, jaise 150 chai' : 'Task likho',
                filled: true,
                fillColor: _bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => Navigator.pop(ctx, c.text.trim()),
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
    if (result == null || result.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() {
      if (isExpense) {
        final amount = double.tryParse(result.split(' ').first) ?? 0;
        expenses.add({'text': result, 'amount': amount});
      } else {
        tasks.add({'text': result, 'done': false});
      }
    });
    _save();
  }

  void _remove(int i, List<Map<String, dynamic>> list) {
    HapticFeedback.lightImpact();
    setState(() => list.removeAt(i));
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final isTask = tab == 0;
    final list = isTask ? tasks : expenses;
    final total = expenses.fold<double>(0, (s, e) => s + (e['amount'] as num).toDouble());
    final done = tasks.where((t) => t['done'] == true).length;

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            children: [
              _header(isTask, total, done),
              Expanded(
                child: list.isEmpty
                    ? _empty(isTask)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _TweenIn(
                          index: i,
                          child: _itemCard(list, i, isTask),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _accent,
        foregroundColor: Colors.black,
        onPressed: _addItem,
        icon: const Icon(Icons.add),
        label: Text(isTask ? 'Task' : 'Kharcha', style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            _navItem(0, Icons.check_circle_outline, 'Tasks'),
            _navItem(1, Icons.currency_rupee, 'Kharcha'),
          ],
        ),
      ),
    );
  }

  Widget _header(bool isTask, double total, int done) {
    final progress = isTask && tasks.isNotEmpty ? done / tasks.length : 0.0;
    final value = isTask ? progress : (expenses.isEmpty ? 0.0 : 1.0);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: isTask ? [_accent, _accent2] : [_accent2, const Color(0xFFFF6B9D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isTask ? 'Aaj ke tasks' : 'Total kharcha',
                    style: const TextStyle(color: Colors.black87, fontSize: 14)),
                const SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: isTask ? done.toDouble() : total),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => Text(
                    isTask ? '${v.round()} / ${tasks.length} done' : '₹${v.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.black, fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => SizedBox(
              width: 60, height: 60,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: v,
                    strokeWidth: 6,
                    backgroundColor: Colors.black12,
                    color: Colors.black,
                  ),
                  Icon(isTask ? Icons.checklist : Icons.payments_outlined, color: Colors.black),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemCard(List<Map<String, dynamic>> list, int i, bool isTask) {
    final item = list[i];
    final isDone = isTask && item['done'] == true;
    return Dismissible(
      key: ValueKey('${tab}_${item['text']}_$i'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _remove(i, list),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDone ? _accent.withOpacity(0.4) : Colors.transparent),
        ),
        child: Row(
          children: [
            if (isTask)
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => item['done'] = !isDone);
                  _save();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone ? _accent : Colors.transparent,
                    border: Border.all(color: isDone ? _accent : _muted, width: 2),
                  ),
                  child: isDone ? const Icon(Icons.check, size: 16, color: Colors.black) : null,
                ),
              )
            else
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: _accent2.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.receipt_long, color: _accent2, size: 20),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  fontSize: 16,
                  color: isDone ? _muted : Colors.white,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                ),
                child: Text(item['text'].toString()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(bool isTask) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isTask ? Icons.task_alt : Icons.savings_outlined, size: 64, color: _muted),
            const SizedBox(height: 12),
            Text(isTask ? 'Koi task nahi' : 'Koi kharcha nahi',
                style: const TextStyle(color: _muted, fontSize: 16)),
          ],
        ),
      );

  Widget _navItem(int i, IconData icon, String label) {
    final selected = tab == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchTab(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? _accent.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? _accent : _muted),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(label, style: const TextStyle(color: _accent, fontWeight: FontWeight.w700)),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Har list item ko thoda-thoda slide + fade karke andar laata hai.
class _TweenIn extends StatelessWidget {
  final int index;
  final Widget child;
  const _TweenIn({required this.index, required this.child});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 350 + (index * 60).clamp(0, 400)),
        curve: Curves.easeOutCubic,
        builder: (_, v, c) => Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, 20 * (1 - v)), child: c),
        ),
        child: child,
      );
}
