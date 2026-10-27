import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class Expense {
  final int? id;
  final String sector;
  final String label;
  final double amount;
  final DateTime date;

  const Expense({this.id, required this.sector, required this.label, required this.amount, required this.date});

  Map<String, Object?> toMap() => {
    'sector': sector,
    'label': label,
    'amount': amount,
    'date': dateKey(date),
  };

  factory Expense.fromMap(Map<String, Object?> row) => Expense(
    id: row['id'] as int,
    sector: row['sector'] as String,
    label: row['label'] as String,
    amount: (row['amount'] as num).toDouble(),
    date: DateTime.parse(row['date'] as String),
  );
}

String dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class ExpenseDatabase {
  ExpenseDatabase._();
  static final ExpenseDatabase instance = ExpenseDatabase._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final directory = await getDatabasesPath();
    _db = await openDatabase(
      join(directory, 'mes_depenses.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE expenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sector TEXT NOT NULL,
            label TEXT NOT NULL,
            amount REAL NOT NULL CHECK(amount > 0),
            date TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_expenses_sector_date ON expenses(sector, date)');
      },
    );
    return _db!;
  }

  Future<List<Expense>> list(String sector, DateTime date, {bool month = false}) async {
    final db = await database;
    final rows = await db.query('expenses',
      where: month ? 'sector = ? AND substr(date, 1, 7) = ?' : 'sector = ? AND date = ?',
      whereArgs: [sector, month ? dateKey(date).substring(0, 7) : dateKey(date)],
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(Expense.fromMap).toList();
  }

  Future<double> allSectorsTotal(DateTime date, {bool month = false}) async {
    final db = await database;
    final result = await db.rawQuery(
      month
        ? 'SELECT COALESCE(SUM(amount), 0) AS total FROM expenses WHERE substr(date, 1, 7) = ?'
        : 'SELECT COALESCE(SUM(amount), 0) AS total FROM expenses WHERE date = ?',
      [month ? dateKey(date).substring(0, 7) : dateKey(date)],
    );
    return (result.first['total'] as num).toDouble();
  }

  Future<void> save(Expense expense) async {
    final db = await database;
    if (expense.id == null) {
      await db.insert('expenses', expense.toMap());
    } else {
      await db.update('expenses', expense.toMap(), where: 'id = ?', whereArgs: [expense.id]);
    }
  }

  Future<void> remove(int id) async {
    final db = await database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }
}
