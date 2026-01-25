// api.dart

import 'models.dart';

// -------------------- "API" helpers (hard-coded for MVP) --------------------

class DebugOverrides {
  Region? region;
  int? temperature;
  int? humidity;
  int? windSpeed;
  int? brightness;
  NoiseLevel? noise;

  bool get anyEnabled =>
      region != null ||
      temperature != null ||
      humidity != null ||
      windSpeed != null ||
      brightness != null ||
      noise != null;

  Environment apply(Environment base) {
    return Environment(
      region: region ?? base.region,
      temperature: temperature ?? base.temperature,
      humidity: humidity ?? base.humidity,
      windSpeed: windSpeed ?? base.windSpeed,
      brightness: brightness ?? base.brightness,
      noise: noise ?? base.noise,
    );
  }

  void clear() {
    region = null;
    temperature = null;
    humidity = null;
    windSpeed = null;
    brightness = null;
    noise = null;
  }
}

class Api {
  static final DebugOverrides debug = DebugOverrides();

  static final Environment _environment = Environment(
    region: Region.rainforest,
    temperature: 22,
    humidity: 68,
    windSpeed: 12,
    brightness: 7,
    noise: NoiseLevel.low,
  );

  static final List<Account> _accounts = [
    const Account(id: 'acc_001', name: 'Checking', balance: 1280),
    const Account(id: 'acc_002', name: 'Savings', balance: 9050),
    const Account(id: 'acc_003', name: 'Treasure Chest', balance: 420),
    const Account(id: 'acc_004', name: 'Travel Fund', balance: 2600),
    const Account(id: 'acc_005', name: 'Guild Treasury', balance: 777),
    const Account(id: 'acc_006', name: 'Credit Card', balance: 1320, isLoan: true),
  ];

  static final List<UserProfile> _users = [
    const UserProfile(id: 'user_001', name: 'Ava Stone'),
    const UserProfile(id: 'user_002', name: 'Milo Reed'),
    const UserProfile(id: 'user_003', name: 'Sage Patel'),
    const UserProfile(id: 'user_004', name: 'Lena Qi'),
  ];

  static final List<Payee> _payees = [
    const Payee(id: 'pay_001', name: 'Metro Utilities'),
    const Payee(id: 'pay_002', name: 'Lumen Mobile'),
    const Payee(id: 'pay_003', name: 'Northwind Insurance'),
    const Payee(id: 'pay_004', name: 'Civic Taxes'),
  ];

  static final Map<String, List<TransactionEntry>> _transactionsByAccount = {
    'acc_001': [
      const TransactionEntry(
        id: 'tx_001',
        description: 'Garden Market',
        amount: 48,
        isDebit: true,
      ),
      const TransactionEntry(
        id: 'tx_002',
        description: 'Payroll',
        amount: 1200,
        isDebit: false,
      ),
      const TransactionEntry(
        id: 'tx_003',
        description: 'Metro Pass',
        amount: 29,
        isDebit: true,
      ),
    ],
    'acc_002': [
      const TransactionEntry(
        id: 'tx_004',
        description: 'Interest',
        amount: 18,
        isDebit: false,
      ),
      const TransactionEntry(
        id: 'tx_005',
        description: 'Rent',
        amount: 920,
        isDebit: true,
      ),
    ],
    'acc_003': [
      const TransactionEntry(
        id: 'tx_006',
        description: 'Puzzle Shop',
        amount: 35,
        isDebit: true,
      ),
    ],
    'acc_004': [
      const TransactionEntry(
        id: 'tx_007',
        description: 'Flight Deposit',
        amount: 310,
        isDebit: true,
      ),
    ],
    'acc_005': [
      const TransactionEntry(
        id: 'tx_008',
        description: 'Vendor Credit',
        amount: 75,
        isDebit: false,
      ),
    ],
    'acc_006': [
      const TransactionEntry(
        id: 'tx_009',
        description: 'Civic Taxes',
        amount: 260,
        isDebit: true,
      ),
      const TransactionEntry(
        id: 'tx_010',
        description: 'Payment Received',
        amount: 140,
        isDebit: false,
      ),
    ],
  };

  static int _txCounter = 1000;

  static Future<Environment> getEnvironment() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return debug.apply(_environment);
  }

  static Future<List<Account>> getAccounts() async {
    await Future.delayed(const Duration(milliseconds: 260));
    return _accounts.map((a) => a).toList();
  }

  static Future<Account> getAccount(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _accounts.firstWhere(
      (a) => a.id == id,
      orElse: () => const Account(id: 'unknown', name: 'Unknown Account', balance: 0),
    );
  }

  static Future<List<UserProfile>> getUsers() async {
    await Future.delayed(const Duration(milliseconds: 220));
    return _users.map((u) => u).toList();
  }

  static Future<List<Payee>> getPayees() async {
    await Future.delayed(const Duration(milliseconds: 220));
    return _payees.map((p) => p).toList();
  }

  static Future<List<TransactionEntry>> getTransactions(String accountId) async {
    await Future.delayed(const Duration(milliseconds: 220));
    return List<TransactionEntry>.from(
      _transactionsByAccount[accountId] ?? const <TransactionEntry>[],
    );
  }

  static Future<List<TransactionEntry>> getTransactionHistory(String userId) async {
    await Future.delayed(const Duration(milliseconds: 240));
    return const <TransactionEntry>[];
  }

  static Future<void> transfer({
    required String fromAccountId,
    required String toAccountId,
    required int amount,
  }) async {
    await Future.delayed(const Duration(milliseconds: 350));
    _applyTransfer(
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      amount: amount,
    );
  }

  static Future<void> send({
    required String fromAccountId,
    required String toUserId,
    required int amount,
  }) async {
    await Future.delayed(const Duration(milliseconds: 350));
    final fromAccount = _accounts.firstWhere(
      (account) => account.id == fromAccountId,
      orElse: () => const Account(id: 'unknown', name: 'Unknown Account', balance: 0),
    );
    if (fromAccount.isLoan) return;
    final name = _userName(toUserId);
    _applyDebit(
      accountId: fromAccountId,
      amount: amount,
      description: 'Send to $name',
    );
  }

  static Future<void> pay({
    required String fromAccountId,
    required String toPayeeId,
    required int amount,
  }) async {
    await Future.delayed(const Duration(milliseconds: 350));
    final name = _payeeName(toPayeeId);
    final fromAccount = _accounts.firstWhere(
      (account) => account.id == fromAccountId,
      orElse: () => const Account(id: 'unknown', name: 'Unknown Account', balance: 0),
    );
    _applyDebit(
      accountId: fromAccountId,
      amount: amount,
      description: 'Pay $name',
      increaseBalance: fromAccount.isLoan,
    );
  }

  static void _applyTransfer({
    required String fromAccountId,
    required String toAccountId,
    required int amount,
  }) {
    if (fromAccountId == toAccountId) return;
    if (amount <= 0) return;

    final fromIndex = _accounts.indexWhere((a) => a.id == fromAccountId);
    final toIndex = _accounts.indexWhere((a) => a.id == toAccountId);
    if (fromIndex == -1 || toIndex == -1) return;

    final fromAccount = _accounts[fromIndex];
    final toAccount = _accounts[toIndex];

    if (fromAccount.isLoan) return;

    final debited = amount > fromAccount.balance ? fromAccount.balance : amount;
    if (debited <= 0) return;

    _accounts[fromIndex] =
        fromAccount.copyWith(balance: fromAccount.balance - debited);
    if (toAccount.isLoan) {
      final newBalance = toAccount.balance - debited;
      _accounts[toIndex] =
          toAccount.copyWith(balance: newBalance < 0 ? 0 : newBalance);
    } else {
      _accounts[toIndex] =
          toAccount.copyWith(balance: toAccount.balance + debited);
    }

    _insertTransaction(
      accountId: fromAccountId,
      description: 'Transfer to ${toAccount.name}',
      amount: debited,
      isDebit: true,
    );
    _insertTransaction(
      accountId: toAccountId,
      description: 'Transfer from ${fromAccount.name}',
      amount: debited,
      isDebit: false,
    );
  }

  static int _applyDebit({
    required String accountId,
    required int amount,
    required String description,
    bool increaseBalance = false,
  }) {
    if (amount <= 0) return 0;
    final index = _accounts.indexWhere((a) => a.id == accountId);
    if (index == -1) return 0;

    final account = _accounts[index];
    if (increaseBalance && account.isLoan) {
      _accounts[index] = account.copyWith(balance: account.balance + amount);
      _insertTransaction(
        accountId: accountId,
        description: description,
        amount: amount,
        isDebit: true,
      );
      return amount;
    }

    final debited = amount > account.balance ? account.balance : amount;
    if (debited <= 0) return 0;
    _accounts[index] = account.copyWith(balance: account.balance - debited);

    _insertTransaction(
      accountId: accountId,
      description: description,
      amount: debited,
      isDebit: true,
    );
    return debited;
  }

  static void _insertTransaction({
    required String accountId,
    required String description,
    required int amount,
    required bool isDebit,
  }) {
    final entry = TransactionEntry(
      id: 'tx_${_txCounter++}',
      description: description,
      amount: amount,
      isDebit: isDebit,
    );
    final list = _transactionsByAccount.putIfAbsent(accountId, () => []);
    list.insert(0, entry);
  }

  static String _userName(String id) {
    return _users.firstWhere(
      (u) => u.id == id,
      orElse: () => const UserProfile(id: 'unknown', name: 'Unknown'),
    ).name;
  }

  static String _payeeName(String id) {
    return _payees.firstWhere(
      (p) => p.id == id,
      orElse: () => const Payee(id: 'unknown', name: 'Unknown Payee'),
    ).name;
  }
}
