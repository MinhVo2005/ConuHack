// view.dart
import 'dart:async';

import 'package:flutter/material.dart';

import 'api.dart';
import 'models.dart';

class BankWorldApp extends StatelessWidget {
  const BankWorldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BankWorld MVP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // Keep app theme neutral; we apply dynamic theming per-screen.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const ListAccountsPage(),
    );
  }
}

// -------------------- Dynamic UI computation --------------------

class WorldUi {
  final Color surface;
  final Color surfaceMuted;
  final Color outline;
  final Color outlineStrong;
  final Color text;
  final Color textMuted;
  final Color pillBg;
  final Color pillFg;
  final Color divider;
  final Color scrimColor;
  final double scrimOpacity;

  final ThemeData theme;

  const WorldUi({
    required this.surface,
    required this.surfaceMuted,
    required this.outline,
    required this.outlineStrong,
    required this.text,
    required this.textMuted,
    required this.pillBg,
    required this.pillFg,
    required this.divider,
    required this.scrimColor,
    required this.scrimOpacity,
    required this.theme,
  });

  static double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

  static Color _on(Color bg) =>
      bg.computeLuminance() > 0.5 ? Colors.black : Colors.white;

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// Replace this with your exact "formula" if you already have one.
  static WorldUi fromStatus(_WorldStatus? s) {
    // Safe defaults while loading.
    final region = s?.region ?? Region.darkCave;
    final temp = s?.weather.temperature ?? 0;
    final hum = s?.weather.humidity ?? 50;
    final wind = s?.weather.windSpeed ?? 10;
    final brightness = (s?.brightness ?? 6).clamp(1, 10);

    // Normalize inputs.
    final tN = _clamp01((temp + 30) / 80); // -30..50 => 0..1
    final hN = _clamp01(hum / 100.0); // 0..100 => 0..1
    final wN = _clamp01(wind / 60.0); // 0..60+ => 0..1
    final bN = _clamp01((brightness - 1) / 9.0); // 1..10 => 0..1

    // "Climate hue": cold->blue, hot->orange/red, humidity shifts toward green.
    final hue = (220.0 * (1 - tN)) + (25.0 * tN) + (20.0 * (hN - 0.5));
    final sat = _clamp01(_lerp(0.45, 0.85, (0.55 * hN + 0.45 * (1 - wN))));
    final light = _clamp01(_lerp(0.28, 0.80, bN));

    final accent = HSLColor.fromAHSL(1, hue % 360, sat, _clamp01(light * 0.9))
        .toColor();

    // Readable surfaces (slightly tinted) and outlines.
    final surface =
        HSLColor.fromAHSL(1, hue % 360, 0.12, _clamp01(_lerp(0.18, 0.92, bN)))
            .toColor()
            .withOpacity(0.86);

    final surfaceMuted =
        HSLColor.fromAHSL(1, hue % 360, 0.08, _clamp01(_lerp(0.14, 0.88, bN)))
            .toColor()
            .withOpacity(0.76);

    // Outline uses accent but adjusted for contrast vs surface.
    final outlineBase = HSLColor.fromColor(accent);
    final outline = outlineBase
        .withSaturation(_clamp01(outlineBase.saturation * 0.65))
        .withLightness(
            _clamp01(surface.computeLuminance() > 0.5 ? 0.18 : 0.85))
        .toColor()
        .withOpacity(0.85);

    final outlineStrong = _on(surface).withOpacity(0.95);
    final text = _on(surface);
    final textMuted = text.withOpacity(0.78);

    // Pill buttons: filled and high-contrast.
    final pillBg = HSLColor.fromColor(accent)
        .withLightness(
            _clamp01(surface.computeLuminance() > 0.5 ? 0.40 : 0.62))
        .toColor();
    final pillFg = _on(pillBg);

    // Scrim: pushes background toward a readable mid-range.
    final bgB = region.bgBrightnessHint;
    final targetBg = _lerp(0.38, 0.62, bN); // ambient light affects how hard we scrub
    final delta = (bgB - targetBg);
    final scrimColor = delta > 0 ? Colors.black : Colors.white;
    final scrimOpacity = _clamp01((delta.abs() * 0.55) + 0.08);

    final divider = outlineStrong.withOpacity(0.85);

    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness:
            surface.computeLuminance() > 0.5 ? Brightness.light : Brightness.dark,
      ),
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: Typography.material2021().black.apply(
        bodyColor: text,
        displayColor: text,
      ),
    );

    return WorldUi(
      surface: surface,
      surfaceMuted: surfaceMuted,
      outline: outline,
      outlineStrong: outlineStrong,
      text: text,
      textMuted: textMuted,
      pillBg: pillBg,
      pillFg: pillFg,
      divider: divider,
      scrimColor: scrimColor,
      scrimOpacity: scrimOpacity,
      theme: theme,
    );
  }
}

class WorldTheme extends InheritedWidget {
  final WorldUi ui;

  const WorldTheme({
    super.key,
    required this.ui,
    required super.child,
  });

  static WorldUi of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<WorldTheme>();
    // If you ever render a widget outside this scope, fall back to defaults.
    return w?.ui ?? WorldUi.fromStatus(null);
  }

  @override
  bool updateShouldNotify(WorldTheme oldWidget) => oldWidget.ui != ui;
}

// -------------------- UI --------------------

class ListAccountsPage extends StatefulWidget {
  const ListAccountsPage({super.key});

  @override
  State<ListAccountsPage> createState() => _ListAccountsPageState();
}

class _ListAccountsPageState extends State<ListAccountsPage> {
  late final Future<User> _userFuture;

  // "Dynamic UI": left panel slides in/out, and only opens when you tap an account.
  bool _leftPanelOpen = false;
  Account? _selectedAccount;

  final ValueNotifier<_WorldStatus?> _world = ValueNotifier<_WorldStatus?>(null);
  Timer? _pollTimer;
  bool _fetchingWorld = false;

  @override
  void initState() {
    super.initState();
    _userFuture = Api.fetchUser();
    _refreshWorld(); // initial
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => _refreshWorld());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _world.dispose();
    super.dispose();
  }

  Future<void> _refreshWorld() async {
    if (_fetchingWorld) return;
    _fetchingWorld = true;
    try {
      final ws = await _loadWorldStatus();
      if (_world.value != ws) {
        _world.value = ws;
      }
    } finally {
      _fetchingWorld = false;
    }
  }

  Future<_WorldStatus> _loadWorldStatus() async {
    // Server ping: ask for all info (concurrently).
    final results = await Future.wait([
      Api.fetchRegion(),
      Api.fetchWeather(),
      Api.fetchNoise(),
      Api.fetchBrightness(),
      Api.fetchLocation(),
      Api.fetchDistanceToNearestTreasure(),
    ]);

    return _WorldStatus(
      region: results[0] as Region,
      weather: results[1] as Weather,
      noise: results[2] as NoiseLevel,
      brightness: results[3] as int,
      location: results[4] as WorldLocation,
      treasureDist: results[5] as DistanceToTreasure,
    );
  }

  void _onAccountTapped(Account a) {
    setState(() {
      _selectedAccount = a;
      _leftPanelOpen = true;
    });
  }

  void _closeLeftPanel() {
    if (!_leftPanelOpen) return;
    setState(() => _leftPanelOpen = false);
  }

  void _noopAction(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label (not wired yet)'),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  void _openDebugMenu() {
    final base = _world.value;
    _showDebugSheet(
      context: context,
      current: base,
      onApply: (patch) {
        // Apply overrides (these change what Api.* returns).
        Api.debug.region = patch.region;
        Api.debug.temperature = patch.temperature;
        Api.debug.humidity = patch.humidity;
        Api.debug.windSpeed = patch.windSpeed;
        Api.debug.noise = patch.noise;
        Api.debug.brightness = patch.brightness;
        Api.debug.location = patch.location;
        Api.debug.treasureDist = patch.treasureDist;
        _refreshWorld();
      },
      onClear: () {
        Api.debug.clear();
        _refreshWorld();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_WorldStatus?>(
      valueListenable: _world,
      builder: (context, ws, _) {
        final uiState = WorldUi.fromStatus(ws);

        return LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 720;
            final screenH = MediaQuery.of(context).size.height;
            final compactPanelH = (screenH * 0.34).clamp(220.0, 300.0);

            return WorldTheme(
              ui: uiState,
              child: AnimatedTheme(
                data: uiState.theme,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: Scaffold(
                  backgroundColor: Colors.transparent,
                  body: Stack(
                    children: [
                      _WorldBackground(region: ws?.region ?? Region.darkCave),
                      // Ambient-light scrim (day/night, too bright/too dark)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            color: uiState.scrimColor.withOpacity(uiState.scrimOpacity),
                          ),
                        ),
                      ),
                      SafeArea(
                        child: FutureBuilder<User>(
                          future: _userFuture,
                          builder: (context, snap) {
                            final user = snap.data;

                            return Column(
                              children: [
                                _TopBar(
                                  compact: isCompact,
                                  onHamburgerPressed: _closeLeftPanel,
                                  onHatPressed: () => _noopAction('Profile'),
                                  onETransfer: () => _noopAction('E-Transfer'),
                                  onTransfer: () => _noopAction('Transfer'),
                                  onPayBills: () => _noopAction('Pay Bills'),
                                  onMore: () => _noopAction('More'),
                                  onDebug: _openDebugMenu,
                                  debugActive: Api.debug.anyEnabled,
                                ),
                                const _ThickDivider(),
                                Expanded(
                                  child: isCompact
                                      ? Stack(
                                          children: [
                                            AnimatedPadding(
                                              duration: const Duration(milliseconds: 220),
                                              curve: Curves.easeOut,
                                              padding: EdgeInsets.fromLTRB(
                                                14,
                                                14,
                                                14,
                                                _leftPanelOpen
                                                    ? compactPanelH + 18
                                                    : 12,
                                              ),
                                              child: _AccountsList(
                                                user: user,
                                                isLoading: snap.connectionState !=
                                                    ConnectionState.done,
                                                onAccountTap: _onAccountTapped,
                                              ),
                                            ),
                                            _SlideUpPanel(
                                              isOpen: _leftPanelOpen,
                                              height: compactPanelH,
                                              onClose: _closeLeftPanel,
                                              onSettings: () => _noopAction('Settings'),
                                              selectedAccount: _selectedAccount,
                                            ),
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            _SlidingLeftPanel(
                                              isOpen: _leftPanelOpen,
                                              onSettings: () => _noopAction('Settings'),
                                              selectedAccount: _selectedAccount,
                                            ),
                                            const _VerticalDividerLine(),
                                            Expanded(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                                child: _AccountsList(
                                                  user: user,
                                                  isLoading:
                                                      snap.connectionState !=
                                                          ConnectionState.done,
                                                  onAccountTap: _onAccountTapped,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                                _BottomWeatherBar(
                                  compact: isCompact,
                                  status: ws,
                                  isLoading: ws == null,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _WorldStatus {
  final Region region;
  final Weather weather;
  final NoiseLevel noise;
  final int brightness;
  final WorldLocation location;
  final DistanceToTreasure treasureDist;

  const _WorldStatus({
    required this.region,
    required this.weather,
    required this.noise,
    required this.brightness,
    required this.location,
    required this.treasureDist,
  });

  @override
  bool operator ==(Object other) {
    return other is _WorldStatus &&
        other.region == region &&
        other.noise == noise &&
        other.brightness == brightness &&
        other.weather.temperature == weather.temperature &&
        other.weather.humidity == weather.humidity &&
        other.weather.windSpeed == weather.windSpeed &&
        other.location.x == location.x &&
        other.location.y == location.y &&
        other.treasureDist.dx == treasureDist.dx &&
        other.treasureDist.dy == treasureDist.dy;
  }

  @override
  int get hashCode => Object.hash(
        region,
        noise,
        brightness,
        weather.temperature,
        weather.humidity,
        weather.windSpeed,
        location.x,
        location.y,
        treasureDist.dx,
        treasureDist.dy,
      );
}

// -------------------- Background --------------------

class _WorldBackground extends StatelessWidget {
  final Region region;
  const _WorldBackground({required this.region});

  @override
  Widget build(BuildContext context) {
    // Fade between region backgrounds when region changes.
    return Positioned.fill(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _RegionBgImage(
          key: ValueKey(region),
          region: region,
        ),
      ),
    );
  }
}

class _RegionBgImage extends StatelessWidget {
  final Region region;
  const _RegionBgImage({super.key, required this.region});

  @override
  Widget build(BuildContext context) {
    // Uses Image.asset with errorBuilder so missing assets don't crash the app.
    return Stack(
      fit: StackFit.expand,
      children: [
        ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            1.1, 0.0, 0.0, 0.0, 0.0,
            0.0, 1.1, 0.0, 0.0, 0.0,
            0.0, 0.0, 1.1, 0.0, 0.0,
            0.0, 0.0, 0.0, 1.0, 0.0,
          ]),
          child: Image.asset(
            region.assetPath,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              // Fallback if assets aren't added yet.
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black.withOpacity(0.25),
                      Colors.white.withOpacity(0.05),
                    ],
                  ),
                ),
                child: Center(
                  child: Text(
                    'Missing asset:\n${region.assetPath}\n\nAdd it to pubspec.yaml',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              );
            },
          ),
        ),
        // A subtle vignette to help readability regardless of image.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 1.2,
              colors: [Colors.transparent, Colors.black38],
              stops: [0.55, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

// -------------------- Widgets --------------------

class _TopBar extends StatelessWidget {
  final bool compact;
  final VoidCallback onHamburgerPressed;
  final VoidCallback onHatPressed;
  final VoidCallback onETransfer;
  final VoidCallback onTransfer;
  final VoidCallback onPayBills;
  final VoidCallback onMore;

  final VoidCallback onDebug;
  final bool debugActive;

  const _TopBar({
    required this.compact,
    required this.onHamburgerPressed,
    required this.onHatPressed,
    required this.onETransfer,
    required this.onTransfer,
    required this.onPayBills,
    required this.onMore,
    required this.onDebug,
    required this.debugActive,
  });

  @override
  Widget build(BuildContext context) {
    final ui = WorldTheme.of(context);

    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: onHamburgerPressed,
                  icon: const Icon(Icons.menu_rounded),
                  tooltip: 'Close panel',
                  color: ui.text,
                ),
                IconButton(
                  onPressed: onHatPressed,
                  icon: const Icon(Icons.account_circle_rounded),
                  tooltip: 'Profile',
                  color: ui.text,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'BankWorld',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: ui.text,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onDebug,
                  tooltip: debugActive ? 'Debug (overrides active)' : 'Debug',
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.bug_report_rounded),
                      if (debugActive)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                  color: ui.text,
                ),
                IconButton(
                  onPressed: onMore,
                  tooltip: 'More',
                  icon: const Icon(Icons.more_horiz_rounded),
                  color: ui.text,
                ),
              ],
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _PillButton(label: 'E-Transfer', onPressed: onETransfer),
                  const SizedBox(width: 10),
                  _PillButton(label: 'Transfer', onPressed: onTransfer),
                  const SizedBox(width: 10),
                  _PillButton(label: 'Pay Bills', onPressed: onPayBills),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onHamburgerPressed,
            icon: const Icon(Icons.menu_rounded),
            tooltip: 'Close left panel',
            color: ui.text,
          ),
          IconButton(
            onPressed: onHatPressed,
            icon: const Icon(Icons.account_circle_rounded),
            tooltip: 'Profile',
            color: ui.text,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Center(
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _PillButton(label: 'E-Transfer', onPressed: onETransfer),
                  _PillButton(label: 'Transfer', onPressed: onTransfer),
                  _PillButton(label: 'Pay Bills', onPressed: onPayBills),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onDebug,
            tooltip: debugActive ? 'Debug (overrides active)' : 'Debug',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.bug_report_rounded),
                if (debugActive)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            color: ui.text,
          ),
          TextButton(
            onPressed: onMore,
            style: TextButton.styleFrom(foregroundColor: ui.text),
            child: const Text('>>'),
          ),
        ],
      ),
    );
  }
}

class _ThickDivider extends StatelessWidget {
  const _ThickDivider();

  @override
  Widget build(BuildContext context) {
    final ui = WorldTheme.of(context);
    return Container(height: 2, color: ui.divider);
  }
}

class _VerticalDividerLine extends StatelessWidget {
  const _VerticalDividerLine();

  @override
  Widget build(BuildContext context) {
    final ui = WorldTheme.of(context);
    return Container(width: 2, color: ui.divider);
  }
}

class _SlidingLeftPanel extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onSettings;
  final Account? selectedAccount;

  const _SlidingLeftPanel({
    required this.isOpen,
    required this.onSettings,
    required this.selectedAccount,
  });

  @override
  Widget build(BuildContext context) {
    final ui = WorldTheme.of(context);

    final screenW = MediaQuery.of(context).size.width;
    final panelW = (screenW * 0.33).clamp(220.0, 320.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: isOpen ? panelW : 0,
      child: ClipRect(
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: isOpen ? 1 : 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ui.surfaceMuted,
                    border: Border.all(color: ui.outline, width: 3),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: ui.outline.withOpacity(0.2),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: const [
                      _SketchBlankBox(height: 72),
                      SizedBox(height: 12),
                      _SketchBlankBox(height: 86),
                      SizedBox(height: 12),
                      _SketchBlankBox(height: 86),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    'Treasure\nHunt',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      color: ui.text,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _PillButton(
                  label: 'Settings',
                  onPressed: onSettings,
                  big: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountsList extends StatelessWidget {
  final User? user;
  final bool isLoading;
  final void Function(Account) onAccountTap;

  const _AccountsList({
    required this.user,
    required this.isLoading,
    required this.onAccountTap,
  });

  @override
  Widget build(BuildContext context) {
    final accounts = user?.accounts ?? const <Account>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                  itemCount: accounts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, i) {
                    final a = accounts[i];
                    return _SketchAccountRow(
                      account: a,
                      onTap: () => onAccountTap(a),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SketchAccountRow extends StatelessWidget {
  final Account account;
  final VoidCallback onTap;

  const _SketchAccountRow({
    required this.account,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ui = WorldTheme.of(context);
    final lastTx =
        account.transactionHistory.isNotEmpty ? account.transactionHistory.first : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: ui.surface,
          border: Border.all(color: ui.outlineStrong, width: 2.5),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: ui.outline.withOpacity(0.18),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: DefaultTextStyle(
                style: TextStyle(color: ui.text),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'ID: ${account.id}',
                      style: TextStyle(fontSize: 12, color: ui.textMuted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Balance: \$${account.balance}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    if (lastTx != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Last tx: ${lastTx.fromAccId} → ${lastTx.toAccId}  (\$${lastTx.dollar})',
                        style: TextStyle(fontSize: 12, color: ui.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.chevron_right_rounded, color: ui.text),
          ],
        ),
      ),
    );
  }
}

class _BottomWeatherBar extends StatelessWidget {
  final bool compact;
  final _WorldStatus? status;
  final bool isLoading;

  const _BottomWeatherBar({
    required this.compact,
    required this.status,
    required this.isLoading,
  });

  String _noiseLabel(NoiseLevel n) {
    switch (n) {
      case NoiseLevel.quiet:
        return 'Quiet';
      case NoiseLevel.low:
        return 'Low';
      case NoiseLevel.med:
        return 'Med';
      case NoiseLevel.high:
        return 'High';
      case NoiseLevel.boomBoom:
        return 'BOOMBOOM';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = WorldTheme.of(context);
    final s = status;

    final cardShadow = [
      BoxShadow(
        color: ui.outline.withOpacity(0.18),
        blurRadius: 14,
        offset: const Offset(0, 8),
      ),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ui.surfaceMuted,
        border: Border.all(color: ui.outlineStrong, width: 2.5),
        borderRadius: BorderRadius.circular(10),
        boxShadow: cardShadow,
      ),
      child: compact
          ? Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ui.surface,
                    border: Border.all(color: ui.outlineStrong, width: 2),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: cardShadow,
                  ),
                  child: isLoading || s == null
                      ? Text('location: ...\n temp, humidity',
                          style: TextStyle(color: ui.text))
                      : Text(
                          'region: ${s.region.label}\n'
                          'loc: (${s.location.x}, ${s.location.y})\n'
                          'temp: ${s.weather.temperature}°C\n'
                          'hum: ${s.weather.humidity}%',
                          style: TextStyle(fontSize: 12, height: 1.25, color: ui.text),
                        ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ui.surface,
                    border: Border.all(color: ui.outlineStrong, width: 2),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: cardShadow,
                  ),
                  child: isLoading || s == null
                      ? Text('Icon (beach / snowy / foresty...)',
                          style: TextStyle(color: ui.text))
                      : Text(
                          'wind: ${s.weather.windSpeed}  •  '
                          'noise: ${_noiseLabel(s.noise)}  •  '
                          'ambient: ${s.brightness}/10  •  '
                          'treasure: (${s.treasureDist.dx}, ${s.treasureDist.dy})',
                          style: TextStyle(fontSize: 12, height: 1.25, color: ui.text),
                        ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  width: 165,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ui.surface,
                    border: Border.all(color: ui.outlineStrong, width: 2),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: cardShadow,
                  ),
                  child: isLoading || s == null
                      ? Text('location: ...\n temp, humidity',
                          style: TextStyle(color: ui.text))
                      : Text(
                          'region: ${s.region.label}\n'
                          'loc: (${s.location.x}, ${s.location.y})\n'
                          'temp: ${s.weather.temperature}°C\n'
                          'hum: ${s.weather.humidity}%',
                          style: TextStyle(fontSize: 12, height: 1.25, color: ui.text),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ui.surface,
                      border: Border.all(color: ui.outlineStrong, width: 2),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: cardShadow,
                    ),
                    child: isLoading || s == null
                        ? Text('Icon (beach / snowy / foresty...)',
                            style: TextStyle(color: ui.text))
                        : Text(
                            'wind: ${s.weather.windSpeed}  •  '
                            'noise: ${_noiseLabel(s.noise)}  •  '
                            'ambient: ${s.brightness}/10  •  '
                            'treasure: (${s.treasureDist.dx}, ${s.treasureDist.dy})',
                            style: TextStyle(fontSize: 12, height: 1.25, color: ui.text),
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SlideUpPanel extends StatelessWidget {
  final bool isOpen;
  final double height;
  final VoidCallback onClose;
  final VoidCallback onSettings;
  final Account? selectedAccount;

  const _SlideUpPanel({
    required this.isOpen,
    required this.height,
    required this.onClose,
    required this.onSettings,
    required this.selectedAccount,
  });

  @override
  Widget build(BuildContext context) {
    final ui = WorldTheme.of(context);
    final account = selectedAccount;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      left: 12,
      right: 12,
      bottom: isOpen ? 12 : -(height + 24),
      height: height,
      child: IgnorePointer(
        ignoring: !isOpen,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              color: ui.surface.withOpacity(0.92),
              border: Border.all(color: ui.outlineStrong, width: 2.5),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: ui.outline.withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ui.text.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Treasure Hunt',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: ui.text,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      tooltip: 'Close',
                      icon: const Icon(Icons.close_rounded),
                      color: ui.text,
                    ),
                  ],
                ),
                if (account != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: ui.surfaceMuted,
                      border: Border.all(color: ui.outline, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${account.name}  •  \$${account.balance}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ui.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Select an account to open the hunt panel.',
                      style: TextStyle(color: ui.textMuted),
                    ),
                  ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ui.surfaceMuted,
                      border: Border.all(color: ui.outline, width: 2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Trail map and inventory\n(placeholder)',
                      style: TextStyle(color: ui.textMuted, height: 1.3),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _PillButton(
                  label: 'Settings',
                  onPressed: onSettings,
                  big: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SketchBlankBox extends StatelessWidget {
  final double height;
  const _SketchBlankBox({required this.height});

  @override
  Widget build(BuildContext context) {
    final ui = WorldTheme.of(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: ui.surface,
        border: Border.all(color: ui.outlineStrong, width: 2.5),
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool big;

  const _PillButton({
    required this.label,
    required this.onPressed,
    this.big = false,
  });

  @override
  Widget build(BuildContext context) {
    final ui = WorldTheme.of(context);

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: big ? 18 : 14,
          vertical: big ? 14 : 10,
        ),
        side: BorderSide(color: ui.outlineStrong, width: 2),
        backgroundColor: ui.pillBg.withOpacity(0.18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        foregroundColor: ui.text,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: big ? 16 : 14,
          color: ui.text,
        ),
      ),
    );
  }
}

// -------------------- Debug sheet (unaffected by dynamic theming) --------------------

Future<void> _showDebugSheet({
  required BuildContext context,
  required _WorldStatus? current,
  required void Function(DebugOverrides patch) onApply,
  required VoidCallback onClear,
}) async {
  final patch = DebugOverrides();

  // Seed patch from current overrides (Api.debug) if you want persistence in the UI.
  patch.region = Api.debug.region ?? current?.region;
  patch.temperature = Api.debug.temperature ?? current?.weather.temperature;
  patch.humidity = Api.debug.humidity ?? current?.weather.humidity;
  patch.windSpeed = Api.debug.windSpeed ?? current?.weather.windSpeed;
  patch.noise = Api.debug.noise ?? current?.noise;
  patch.brightness = Api.debug.brightness ?? current?.brightness;
  patch.location = Api.debug.location ?? current?.location;
  patch.treasureDist = Api.debug.treasureDist ?? current?.treasureDist;

  final fixedDebugTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
  );

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      return Theme(
        data: fixedDebugTheme, // debug menu ignores WorldUi / background / etc.
        child: StatefulBuilder(
          builder: (ctx, setLocal) {
            Widget sectionTitle(String t) => Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 6),
                  child: Text(t, style: const TextStyle(fontWeight: FontWeight.w900)),
                );

            Widget sliderInt({
              required String label,
              required int min,
              required int max,
              required int? value,
              required void Function(int v) onChanged,
            }) {
              final v = (value ?? min).clamp(min, max);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$label: $v'),
                  Slider(
                    value: v.toDouble(),
                    min: min.toDouble(),
                    max: max.toDouble(),
                    divisions: (max - min),
                    onChanged: (d) => setLocal(() => onChanged(d.round())),
                  ),
                ],
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 14,
                bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Debug Overrides',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            onClear();
                            Navigator.of(ctx).pop();
                          },
                          child: const Text('Clear all'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    sectionTitle('Region'),
                    DropdownButtonFormField<Region>(
                      value: patch.region ?? Region.darkCave,
                      items: Region.values
                          .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                          .toList(),
                      onChanged: (r) => setLocal(() => patch.region = r),
                    ),

                    sectionTitle('Ambient light (1..10)'),
                    sliderInt(
                      label: 'Brightness',
                      min: 1,
                      max: 10,
                      value: patch.brightness,
                      onChanged: (v) => patch.brightness = v,
                    ),

                    sectionTitle('Weather'),
                    sliderInt(
                      label: 'Temperature (°C)',
                      min: -30,
                      max: 50,
                      value: patch.temperature,
                      onChanged: (v) => patch.temperature = v,
                    ),
                    sliderInt(
                      label: 'Humidity (%)',
                      min: 0,
                      max: 100,
                      value: patch.humidity,
                      onChanged: (v) => patch.humidity = v,
                    ),
                    sliderInt(
                      label: 'Wind speed',
                      min: 0,
                      max: 60,
                      value: patch.windSpeed,
                      onChanged: (v) => patch.windSpeed = v,
                    ),

                    sectionTitle('Noise'),
                    DropdownButtonFormField<NoiseLevel>(
                      value: patch.noise ?? NoiseLevel.med,
                      items: NoiseLevel.values
                          .map((n) => DropdownMenuItem(value: n, child: Text(n.name)))
                          .toList(),
                      onChanged: (n) => setLocal(() => patch.noise = n),
                    ),

                    sectionTitle('Location'),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue:
                                (patch.location?.x ?? current?.location.x ?? 0).toString(),
                            decoration: const InputDecoration(labelText: 'x'),
                            keyboardType: TextInputType.number,
                            onChanged: (t) {
                              final x = int.tryParse(t) ?? 0;
                              final y = patch.location?.y ?? current?.location.y ?? 0;
                              patch.location = WorldLocation(x, y);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            initialValue:
                                (patch.location?.y ?? current?.location.y ?? 0).toString(),
                            decoration: const InputDecoration(labelText: 'y'),
                            keyboardType: TextInputType.number,
                            onChanged: (t) {
                              final y = int.tryParse(t) ?? 0;
                              final x = patch.location?.x ?? current?.location.x ?? 0;
                              patch.location = WorldLocation(x, y);
                            },
                          ),
                        ),
                      ],
                    ),

                    sectionTitle('Treasure distance'),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: (patch.treasureDist?.dx ??
                                    current?.treasureDist.dx ??
                                    0)
                                .toString(),
                            decoration: const InputDecoration(labelText: 'dx'),
                            keyboardType: TextInputType.number,
                            onChanged: (t) {
                              final dx = int.tryParse(t) ?? 0;
                              final dy = patch.treasureDist?.dy ?? current?.treasureDist.dy ?? 0;
                              patch.treasureDist = DistanceToTreasure(dx, dy);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            initialValue: (patch.treasureDist?.dy ??
                                    current?.treasureDist.dy ??
                                    0)
                                .toString(),
                            decoration: const InputDecoration(labelText: 'dy'),
                            keyboardType: TextInputType.number,
                            onChanged: (t) {
                              final dy = int.tryParse(t) ?? 0;
                              final dx = patch.treasureDist?.dx ?? current?.treasureDist.dx ?? 0;
                              patch.treasureDist = DistanceToTreasure(dx, dy);
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        onApply(patch);
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Apply + Refresh'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
