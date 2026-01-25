// api.dart

import 'models.dart';

// -------------------- "API" helpers (hard-coded for MVP) --------------------
// NOTE: Debug menu changes what these hardcoded functions return.

class Api {
  static final DebugOverrides debug = DebugOverrides();

  static Future<User> fetchUser() async {
    await Future.delayed(const Duration(milliseconds: 250));
    final accounts = await fetchAccountsForUser("user_001");
    return User(
      id: "user_001",
      accounts: accounts,
      creditScore: 742,
    );
  }

  static Future<List<Account>> fetchAccountsForUser(String userId) async {
    await Future.delayed(const Duration(milliseconds: 250));

    const t1 = Transaction(fromAccId: "acc_001", toAccId: "acc_999", dollar: 25);
    const t2 = Transaction(fromAccId: "acc_002", toAccId: "acc_001", dollar: 90);
    const t3 = Transaction(fromAccId: "acc_003", toAccId: "acc_002", dollar: 12);

    return const [
      Account(
        name: "Chequing (Town Bank)",
        id: "acc_001",
        balance: 1280,
        transactionHistory: [t1, t2],
      ),
      Account(
        name: "Savings (Forest Credit Union)",
        id: "acc_002",
        balance: 9050,
        transactionHistory: [t2, t3],
      ),
      Account(
        name: "Loot Vault (Dungeon Bank)",
        id: "acc_003",
        balance: 420,
        transactionHistory: [t3],
      ),
      Account(
        name: "Quest Fund (Beach Bank)",
        id: "acc_004",
        balance: 2600,
        transactionHistory: [],
      ),
      Account(
        name: "Guild Treasury (Snow Bank)",
        id: "acc_005",
        balance: 777,
        transactionHistory: [],
      ),
    ];
  }

  static Future<Region> fetchRegion() async {
    await Future.delayed(const Duration(milliseconds: 120));
    return debug.region ?? Region.darkCave;
  }

  static Future<Weather> fetchWeather() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return Weather(
      temperature: debug.temperature ?? -4,
      humidity: debug.humidity ?? 61,
      windSpeed: debug.windSpeed ?? 18,
    );
  }

  static Future<NoiseLevel> fetchNoise() async {
    await Future.delayed(const Duration(milliseconds: 180));
    return debug.noise ?? NoiseLevel.med;
  }

  static Future<int> fetchBrightness() async {
    await Future.delayed(const Duration(milliseconds: 180));
    return debug.brightness ?? 6; // 1-10
  }

  static Future<WorldLocation> fetchLocation() async {
    await Future.delayed(const Duration(milliseconds: 180));
    return debug.location ?? const WorldLocation(12, -7);
  }

  static Future<DistanceToTreasure> fetchDistanceToNearestTreasure() async {
    await Future.delayed(const Duration(milliseconds: 180));
    return debug.treasureDist ?? const DistanceToTreasure(3, 11);
  }
}
