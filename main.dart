import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ExpensesApp());
}

const sectors = ['Agricole', 'Magasin', 'Atelier', 'Autre'];
const icons = [Icons.agriculture, Icons.storefront, Icons.handyman, Icons.category];
final currency = NumberFormat.currency(locale: 'fr', symbol: 'DT', decimalDigits: 3);

class ExpensesApp extends StatelessWidget {
  const ExpensesApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Mes Dépenses',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF176B59)),
    home: const ExpensesHome(),
  );
}

class ExpensesHome extends StatefulWidget {
  const ExpensesHome({super.key});
  @override
  State<ExpensesHome> createState() => _ExpensesHomeState();
}

class _ExpensesHomeState extends State<ExpensesHome> {
  String sector = sectors.first;
  DateTime date = DateTime.now();
  bool monthly = false;
  bool grouped = false;
  bool loading = true;
  List<Expense> expenses = [];
  double overallTotal = 0;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() => loading = true);
    try {
      final result = await Future.wait([
        ExpenseDatabase.instance.list(sector, date, month: monthly),
        ExpenseDatabase.instance.allSectorsTotal(date, month: monthly),
      ]);
      if (!mounted) return;
      setState(() {
        expenses = result[0] as List<Expense>;
        overallTotal = result[1] as double;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur de lecture : $error')));
    }
  }

  Future<void> pickDate() async {
    final chosen = await showDatePicker(
      context: context, initialDate: date,
      firstDate: DateTime(2000), lastDate: DateTime(2100),
    );
    if (chosen != null) {
      setState(() => date = chosen);
      await refresh();
    }
  }

  Future<void> editExpense([Expense? existing]) async {
    final labelController = TextEditingController(text: existing?.label ?? '');
    final amountController = TextEditingController(text: existing?.amount.toString().replaceAll('.', ',') ?? '');
    DateTime selectedDate = existing?.date ?? date;
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: Text(existing == null ? 'Nouvelle dépense' : 'Modifier la dépense'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: labelController, autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Libellé'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Libellé obligatoire' : null,
                ),
                TextFormField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Montant (DT)'),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').replaceAll(',', '.').trim());
                    return n == null || !n.isFinite || n <= 0 ? 'Saisir un montant positif' : null;
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context, initialDate: selectedDate,
                      firstDate: DateTime(2000), lastDate: DateTime(2100),
                    );
                    if (picked != null) updateDialog(() => selectedDate = picked);
                  },
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await ExpenseDatabase.instance.save(Expense(
                  id: existing?.id,
                  sector: existing?.sector ?? sector,
                  label: labelController.text.trim(),
                  amount: double.parse(amountController.text.trim().replaceAll(',', '.')),
                  date: selectedDate,
                ));
                if (context.mounted) Navigator.pop(context, true);
              } catch (error) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enregistrement impossible : $error')));
              }
            }, child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
    labelController.dispose();
    amountController.dispose();
    if (saved == true) await refresh();
  }

  Future<void> deleteExpense(Expense expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette dépense ?'),
        content: Text('${expense.label} — ${currency.format(expense.amount)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirm == true && expense.id != null) {
      await ExpenseDatabase.instance.remove(expense.id!);
      await refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sectorTotal = expenses.fold<double>(0, (sum, item) => sum + item.amount);
    final Map<String, double> totalsByLabel = {};
    for (final expense in expenses) {
      final key = expense.label.trim().toLowerCase();
      totalsByLabel[key] = (totalsByLabel[key] ?? 0) + expense.amount;
    }
    final labels = <String, String>{};
    for (final expense in expenses) {
      labels.putIfAbsent(expense.label.trim().toLowerCase(), () => expense.label.trim());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mes Dépenses'), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editExpense(),
        icon: const Icon(Icons.add), label: const Text('Ajouter'),
      ),
      body: SafeArea(child: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Card(color: Theme.of(context).colorScheme.primaryContainer, child: Padding(
            padding: const EdgeInsets.all(20), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Total de tous les secteurs'),
                const SizedBox(height: 6),
                Text(currency.format(overallTotal), style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
          )),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < sectors.length; i++)
              ChoiceChip(
                avatar: Icon(icons[i], size: 18),
                label: Text(sectors[i]), selected: sector == sectors[i],
                onSelected: (_) { setState(() => sector = sectors[i]); refresh(); },
              ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: SegmentedButton<bool>(
              segments: const [ButtonSegment(value: false, label: Text('Jour')), ButtonSegment(value: true, label: Text('Mois'))],
              selected: {monthly},
              onSelectionChanged: (value) { setState(() => monthly = value.first); refresh(); },
            )),
            const SizedBox(width: 8),
            IconButton.filledTonal(onPressed: pickDate, icon: const Icon(Icons.calendar_month), tooltip: 'Choisir une date'),
          ]),
          Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(
            monthly ? DateFormat('MM/yyyy').format(date) : DateFormat('dd/MM/yyyy').format(date),
            style: Theme.of(context).textTheme.titleMedium,
          )),
          Text('Total $sector : ${currency.format(sectorTotal)}', style: Theme.of(context).textTheme.titleLarge),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Regrouper par libellé'),
            subtitle: const Text('Additionner les libellés identiques'),
            value: grouped, onChanged: (value) => setState(() => grouped = value),
          ),
          const Divider(),
          if (loading) const Center(child: CircularProgressIndicator())
          else if (expenses.isEmpty) const Padding(
            padding: EdgeInsets.all(30), child: Center(child: Text('Aucune dépense pour cette période.')),
          )
          else if (grouped)
            for (final entry in totalsByLabel.entries)
              ListTile(
                title: Text(labels[entry.key]!),
                trailing: Text(currency.format(entry.value), style: const TextStyle(fontWeight: FontWeight.bold)),
              )
          else
            for (final expense in expenses)
              Card(child: ListTile(
                title: Text(expense.label),
                subtitle: Text(DateFormat('dd/MM/yyyy').format(expense.date)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(currency.format(expense.amount)),
                  PopupMenuButton<String>(
                    onSelected: (action) => action == 'edit' ? editExpense(expense) : deleteExpense(expense),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Modifier')),
                      PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                    ],
                  ),
                ]),
              )),
          const SizedBox(height: 85),
        ]),
      )),
    );
  }
}
