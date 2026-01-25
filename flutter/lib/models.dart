// models.dart

// -------------------- World / Region --------------------

enum Region {
  dryBeach,
  darkCave,
  loudJungle,
  windyPlains,
  rainforest,
  arcticSnows,
}

extension RegionX on Region {
  String get label {
    switch (this) {
      case Region.dryBeach:
        return 'Dry beach';
      case Region.darkCave:
        return 'Dark cave';
      case Region.loudJungle:
        return 'Loud jungle';
      case Region.windyPlains:
        return 'Windy plains';
      case Region.rainforest:
        return 'Rainforest';
      case Region.arcticSnows:
        return 'Arctic snows';
    }
  }

  ///   assets/bg/beach.jpg
  ///   assets/bg/cave.jpg
  ///   assets/bg/jungle.jpg
  ///   assets/bg/plains.jpg
  ///   assets/bg/rainforest.jpg
  ///   assets/bg/arctic.jpg
  ///  add to pubspec.yaml under `assets:`.
  String get assetPath {
    switch (this) {
      case Region.dryBeach:
        return 'assets/bg/beach.jpg';
      case Region.darkCave:
        return 'assets/bg/cave.jpg';
      case Region.loudJungle:
        return 'assets/bg/jungle.jpg';
      case Region.windyPlains:
        return 'assets/bg/plains.jpg';
      case Region.rainforest:
        return 'assets/bg/rainforest.jpg';
      case Region.arcticSnows:
        return 'assets/bg/arctic.jpg';
    }
  }

  /// Rough brightness estimate of the background image (0..1).
  double get bgBrightnessHint {
    switch (this) {
      case Region.dryBeach:
        return 0.85;
      case Region.darkCave:
        return 0.15;
      case Region.loudJungle:
        return 0.45;
      case Region.windyPlains:
        return 0.65;
      case Region.rainforest:
        return 0.35;
      case Region.arcticSnows:
        return 0.90;
    }
  }
}

// -------------------- Environment --------------------

enum NoiseLevel { quiet, low, med, high, boomBoom }

class Environment {
  final Region region;
  final int temperature;
  final int humidity;
  final int windSpeed;
  final int brightness;
  final NoiseLevel noise;

  const Environment({
    required this.region,
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.brightness,
    required this.noise,
  });
}

// -------------------- Data model --------------------

class Account {
  final String id;
  final String name;
  final int balance;
  final bool isLoan;
  final String? type; // checking, savings, treasure_chest

  const Account({
    required this.id,
    required this.name,
    required this.balance,
    this.isLoan = false,
    this.type,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      isLoan: json['is_loan'] ?? false,
      type: json['type'],
    );
  }

  Account copyWith({
    String? id,
    String? name,
    int? balance,
    bool? isLoan,
    String? type,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      isLoan: isLoan ?? this.isLoan,
      type: type ?? this.type,
    );
  }
}

class UserProfile {
  final String id;
  final String name;

  const UserProfile({
    required this.id,
    required this.name,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
    );
  }
}

class TransactionEntry {
  final String id;
  final String description;
  final int amount;
  final bool isDebit;
  final String? type;
  final int? fromAccountId;
  final int? toAccountId;

  const TransactionEntry({
    required this.id,
    required this.description,
    required this.amount,
    required this.isDebit,
    this.type,
    this.fromAccountId,
    this.toAccountId,
  });

  factory TransactionEntry.fromJson(
    Map<String, dynamic> json, {
    int? forAccountId,
    bool accountIsLoan = false,
  }) {
    final type = json['type'] ?? '';
    final fromId = json['from_account_id'] as int?;
    final toId = json['to_account_id'] as int?;

    // Determine if this is a debit based on transaction type and account context
    bool isDebit;
    if (forAccountId != null) {
      // If we know which account we're viewing, check if money left that account
      isDebit = fromId == forAccountId;
      if (accountIsLoan) {
        isDebit = !isDebit;
      }
    } else {
      // Fallback: use transaction type
      isDebit = type == 'withdrawal' || type == 'transfer';
    }

    // Generate description if not provided
    String description = json['description'] ?? '';
    if (description.isEmpty) {
      switch (type) {
        case 'transfer':
          description = isDebit ? 'Transfer out' : 'Transfer in';
          break;
        case 'deposit':
          description = 'Deposit';
          break;
        case 'withdrawal':
          description = 'Withdrawal';
          break;
        case 'gold_exchange':
          description = 'Gold Exchange';
          break;
        default:
          description = 'Transaction';
      }
    }

    return TransactionEntry(
      id: json['id']?.toString() ?? '',
      description: description,
      amount: ((json['amount'] as num?)?.abs().toInt()) ?? 0,
      isDebit: isDebit,
      type: type,
      fromAccountId: fromId,
      toAccountId: toId,
    );
  }
}

class Payee {
  final String id;
  final String name;

  const Payee({
    required this.id,
    required this.name,
  });

  factory Payee.fromJson(Map<String, dynamic> json) {
    return Payee(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
    );
  }
}
