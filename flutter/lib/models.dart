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

  const Account({
    required this.id,
    required this.name,
    required this.balance,
    this.isLoan = false,
  });

  Account copyWith({
    String? id,
    String? name,
    int? balance,
    bool? isLoan,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      isLoan: isLoan ?? this.isLoan,
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
}

class TransactionEntry {
  final String id;
  final String description;
  final int amount;
  final bool isDebit;

  const TransactionEntry({
    required this.id,
    required this.description,
    required this.amount,
    required this.isDebit,
  });
}

class Payee {
  final String id;
  final String name;

  const Payee({
    required this.id,
    required this.name,
  });
}
