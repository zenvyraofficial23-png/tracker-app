import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Tracker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> tasks = [];
  List<Map<String, dynamic>> expenses = [];
  int tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _addItem(bool isExpense) async {
    final c = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isExpense ? 'Naya kharcha' : 'Naya task'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: InputDecoration(
            hintText: isExpense ? 'Amount pehle, jaise 150 chai' : 'Task likho',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
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

  @override
  Widget build(BuildContext context) {
    final isTask = tab == 0;
    final list = isTask ? tasks : expenses;
    final total = expenses.fold<double>(0, (s, e) => s + (e['amount'] as num).toDouble());

    return Scaffold(
      appBar: AppBar(title: Text(isTask ? 'Tasks' : 'Expenses')),
      body: Column(
        children: [
          if (!isTask)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Total: ₹${total.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('Abhi kuch nahi hai. + dabao'))
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final item = list[i];
                      return ListTile(
                        leading: isTask
                            ? Checkbox(
                                value: item['done'],
                                onChanged: (v) {
                                  setState(() => item['done'] = v);
                                  _save();
                                },
                              )
                            : const Icon(Icons.receipt_long),
                        title: Text(
                          item['text'],
                          style: TextStyle(
                            decoration: isTask && item['done'] == true
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            setState(() => list.removeAt(i));
                            _save();
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addItem(!isTask),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.check_circle_outline), label: 'Tasks'),
          NavigationDestination(icon: Icon(Icons.currency_rupee), label: 'Expenses'),
        ],
      ),
    );
  }
}
