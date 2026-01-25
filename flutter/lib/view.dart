// view.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'api.dart';
import 'models.dart';
import 'backend_service.dart';
import 'voice_command_service.dart' show AccountRefreshNotifier;

ThemeData _buildTheme(BankColors colors) {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: colors.surface,
    colorScheme: ColorScheme.light(
      primary: colors.text,
      onPrimary: colors.surface,
      surface: colors.surface,
      onSurface: colors.text,
      outline: colors.divider,
    ),
    dividerColor: colors.divider,
    iconTheme: IconThemeData(color: colors.text),
    textTheme: Typography.material2021().black.apply(
          bodyColor: colors.text,
          displayColor: colors.text,
        ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      hintStyle: TextStyle(color: colors.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.text, width: 1.5),
      ),
    ),
  );
}

class BankColors {
  final Color text;
  final Color textMuted;
  final Color surface;
  final Color surfaceMuted;
  final Color divider;
  final Color shadow;
  final Color headerScrimTop;
  final Color headerScrimBottom;
  final Color actionFill;

  const BankColors({
    required this.text,
    required this.textMuted,
    required this.surface,
    required this.surfaceMuted,
    required this.divider,
    required this.shadow,
    required this.headerScrimTop,
    required this.headerScrimBottom,
    required this.actionFill,
  });

  factory BankColors.light() {
    return const BankColors(
      text: Colors.black,
      textMuted: Color(0xFF4A4A4A),
      surface: Colors.white,
      surfaceMuted: Color(0xFFF6F6F6),
      divider: Color(0xFFE4E4E4),
      shadow: Color(0x14000000),
      headerScrimTop: Color(0xE6FFFFFF),
      headerScrimBottom: Color(0x99FFFFFF),
      actionFill: Color(0xFFF2F2F2),
    );
  }

  factory BankColors.forRegion(Region region) {
    switch (region) {
      case Region.arcticSnows:
        return const BankColors(
          text: Color(0xFF0E2A3A),
          textMuted: Color(0xFF416679),
          surface: Color(0xFFF7FBFF),
          surfaceMuted: Color(0xFFE5F2FA),
          divider: Color(0xFFCFE0EA),
          shadow: Color(0x140B2230),
          headerScrimTop: Color(0xE6F2F8FF),
          headerScrimBottom: Color(0x99E3F1FB),
          actionFill: Color(0xFFD7ECF7),
        );
      case Region.rainforest:
        return const BankColors(
          text: Color(0xFF1A2F22),
          textMuted: Color(0xFF3C5A46),
          surface: Color(0xFFF1F7F2),
          surfaceMuted: Color(0xFFE0EDE2),
          divider: Color(0xFFC6D9CA),
          shadow: Color(0x1A102219),
          headerScrimTop: Color(0xE6EAF4EC),
          headerScrimBottom: Color(0x99D2E3D5),
          actionFill: Color(0xFFD6E7DA),
        );
      case Region.windyPlains:
        return const BankColors(
          text: Color(0xFF1E2A39),
          textMuted: Color(0xFF4A6175),
          surface: Color(0xFFF3F7FB),
          surfaceMuted: Color(0xFFE1ECF5),
          divider: Color(0xFFC7D8E6),
          shadow: Color(0x160F2230),
          headerScrimTop: Color(0xE6F6FAFF),
          headerScrimBottom: Color(0x99DDE9F5),
          actionFill: Color(0xFFD7E6F2),
        );
      case Region.dryBeach:
        return const BankColors(
          text: Color(0xFF3A2A12),
          textMuted: Color(0xFF6C4E2E),
          surface: Color(0xFFFFF3E0),
          surfaceMuted: Color(0xFFF5E2C8),
          divider: Color(0xFFE6D0B0),
          shadow: Color(0x1A3A2A12),
          headerScrimTop: Color(0xE6FFF7EA),
          headerScrimBottom: Color(0x99F5E0C7),
          actionFill: Color(0xFFF4E0BD),
        );
      case Region.loudJungle:
        return const BankColors(
          text: Color(0xFF1B2E1E),
          textMuted: Color(0xFF3E5C42),
          surface: Color(0xFFF2F7F2),
          surfaceMuted: Color(0xFFE0EDE3),
          divider: Color(0xFFC8D9CC),
          shadow: Color(0x1A122418),
          headerScrimTop: Color(0xE6EEF6EF),
          headerScrimBottom: Color(0x99D7E6DA),
          actionFill: Color(0xFFDAE8DE),
        );
      case Region.darkCave:
        return const BankColors(
          text: Color(0xFF1A1F2A),
          textMuted: Color(0xFF4A5666),
          surface: Color(0xFFF0F3F8),
          surfaceMuted: Color(0xFFE1E7F0),
          divider: Color(0xFFC7D2E0),
          shadow: Color(0x1A0F1218),
          headerScrimTop: Color(0xE6F4F6FA),
          headerScrimBottom: Color(0x99D5DDE8),
          actionFill: Color(0xFFDCE4EF),
        );
    }
  }

  static const Color _coldTint = Color(0xFF78C6FF);
  static const Color _warmTint = Color(0xFFFFB05A);
  static const Color _dryTint = Color(0xFFE0C28C);
  static const Color _humidTint = Color(0xFF6FC9A2);

  factory BankColors.forEnvironment({
    required Region region,
    int? temperature,
    int? humidity,
    int? brightness,
  }) {
    final base = BankColors.forRegion(region);
    final tempT = temperature == null
        ? 0.5
        : _normalize(temperature.toDouble(), -10, 38);
    final humidityT = humidity == null
        ? 0.5
        : _normalize(humidity.toDouble(), 20, 90);

    final tempTint = Color.lerp(_coldTint, _warmTint, tempT)!;
    final humidityTint = Color.lerp(_dryTint, _humidTint, humidityT)!;

    final tempExt = (tempT - 0.5).abs() * 2;
    final humidityExt = (humidityT - 0.5).abs() * 2;

    var tempWeight = temperature == null
        ? 0.0
        : (0.25 + 0.45 * tempExt) * _regionTempWeight(region);
    var humidityWeight = humidity == null
        ? 0.0
        : (0.2 + 0.4 * humidityExt) * _regionHumidityWeight(region);
    tempWeight = tempWeight.clamp(0.0, 0.65).toDouble();
    humidityWeight = humidityWeight.clamp(0.0, 0.65).toDouble();

    Color blend(Color color, double strength) {
      var out = Color.lerp(color, tempTint, strength * tempWeight)!;
      out = Color.lerp(out, humidityTint, strength * humidityWeight)!;
      return out;
    }

    final brightnessT = brightness == null
        ? 0.5
        : _normalize(brightness.toDouble(), 1, 10);
    final brighten = brightnessT >= 0.5;
    final brightnessStrength = (brightnessT - 0.5).abs() * 2;
    final brightnessWeight = (0.12 + 0.38 * brightnessStrength)
        .clamp(0.12, 0.5)
        .toDouble();

    Color applyBrightness(Color color,
        {double strength = 1, bool forText = false}) {
      if (brightnessT == 0.5) return color;
      final target = brighten ? Colors.white : Colors.black;
      final textScale = forText ? 0.5 : 1.0;
      final weight = brightnessWeight * strength * textScale;
      return Color.lerp(color, target, weight) ?? color;
    }

    return BankColors(
      text: applyBrightness(blend(base.text, 0.18),
          strength: 0.5, forText: true),
      textMuted: applyBrightness(blend(base.textMuted, 0.26),
          strength: 0.6, forText: true),
      surface: applyBrightness(blend(base.surface, 0.7)),
      surfaceMuted: applyBrightness(blend(base.surfaceMuted, 0.75)),
      divider: applyBrightness(blend(base.divider, 0.48), strength: 0.7),
      shadow: base.shadow,
      headerScrimTop: applyBrightness(blend(base.headerScrimTop, 0.65),
          strength: 0.9),
      headerScrimBottom: applyBrightness(blend(base.headerScrimBottom, 0.65),
          strength: 0.9),
      actionFill: applyBrightness(blend(base.actionFill, 0.75)),
    );
  }

  static double _normalize(double value, double min, double max) {
    if (max - min == 0) return 0.5;
    return ((value - min) / (max - min)).clamp(0.0, 1.0).toDouble();
  }

  static double _regionTempWeight(Region region) {
    switch (region) {
      case Region.dryBeach:
        return 1.2;
      case Region.rainforest:
        return 0.9;
      case Region.windyPlains:
        return 1.0;
      case Region.arcticSnows:
        return 1.3;
      case Region.loudJungle:
        return 1.0;
      case Region.darkCave:
        return 0.8;
    }
  }

  static double _regionHumidityWeight(Region region) {
    switch (region) {
      case Region.dryBeach:
        return 0.7;
      case Region.rainforest:
        return 1.3;
      case Region.windyPlains:
        return 0.9;
      case Region.arcticSnows:
        return 0.8;
      case Region.loudJungle:
        return 1.1;
      case Region.darkCave:
        return 0.8;
    }
  }
}

class BankTheme extends InheritedWidget {
  final BankColors colors;

  const BankTheme({
    super.key,
    required this.colors,
    required super.child,
  });

  static BankColors of(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<BankTheme>();
    return theme?.colors ?? BankColors.light();
  }

  @override
  bool updateShouldNotify(BankTheme oldWidget) => colors != oldWidget.colors;
}

class BankEffects extends InheritedWidget {
  final Environment? environment;
  final double windIntensity;
  final double shakeIntensity;

  const BankEffects({
    super.key,
    required this.environment,
    required this.windIntensity,
    required this.shakeIntensity,
    required super.child,
  });

  static BankEffects? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<BankEffects>();
  }

  @override
  bool updateShouldNotify(covariant BankEffects oldWidget) {
    return environment != oldWidget.environment ||
        windIntensity != oldWidget.windIntensity ||
        shakeIntensity != oldWidget.shakeIntensity;
  }
}

class PageEntrance extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Offset offset;

  const PageEntrance({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 420),
    this.offset = const Offset(0, 0.03),
  });

  @override
  State<PageEntrance> createState() => _PageEntranceState();
}

class _PageEntranceState extends State<PageEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: widget.offset,
    end: Offset.zero,
  ).animate(_opacity);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

double _headerHeight(BuildContext context, double fraction,
    {double min = 200, double max = 320}) {
  final height = MediaQuery.of(context).size.height * fraction;
  return height.clamp(min, max);
}

String _formatBalance(int amount) => '\$$amount CAD';
String _formatAmount(int amount) => '\$$amount';

class RegionHeader extends StatelessWidget {
  final Region? region;
  final double height;
  final Widget child;

  const RegionHeader({
    super.key,
    required this.region,
    required this.height,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = BankTheme.of(context);
    final safeRegion = region ?? Region.darkCave;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _RegionBackground(region: safeRegion),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.headerScrimTop, colors.headerScrimBottom],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _RegionBackground extends StatelessWidget {
  final Region region;

  const _RegionBackground({required this.region});

  @override
  Widget build(BuildContext context) {
    final colors = BankTheme.of(context);
    return Image.asset(
      region.assetPath,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return Container(color: colors.surfaceMuted);
      },
    );
  }
}

enum _WeatherType { none, snow, rain, wind }

_WeatherType _weatherForRegion(Region region) {
  switch (region) {
    case Region.arcticSnows:
      return _WeatherType.snow;
    case Region.rainforest:
      return _WeatherType.rain;
    case Region.windyPlains:
      return _WeatherType.wind;
    case Region.dryBeach:
    case Region.darkCave:
    case Region.loudJungle:
      return _WeatherType.none;
  }
}

class _WeatherPalette {
  final Color highlight;
  final Color accent;

  const _WeatherPalette({
    required this.highlight,
    required this.accent,
  });
}

_WeatherPalette _weatherPalette(Region region, BankColors colors) {
  switch (region) {
    case Region.arcticSnows:
      return const _WeatherPalette(
        highlight: Color(0xFFFDFEFF),
        accent: Color(0xFFBFDFF5),
      );
    case Region.rainforest:
      return const _WeatherPalette(
        highlight: Color(0xFF9FC3E3),
        accent: Color(0xFF6F96BD),
      );
    case Region.windyPlains:
      return const _WeatherPalette(
        highlight: Color(0xFFD5E4F3),
        accent: Color(0xFF9AB8D4),
      );
    case Region.dryBeach:
    case Region.darkCave:
    case Region.loudJungle:
      return _WeatherPalette(
        highlight: colors.surface,
        accent: colors.surfaceMuted,
      );
  }
}

class NoiseShake extends StatefulWidget {
  final double intensity;
  final Widget child;

  const NoiseShake({
    super.key,
    required this.intensity,
    required this.child,
  });

  @override
  State<NoiseShake> createState() => _NoiseShakeState();
}

class _NoiseShakeState extends State<NoiseShake> with SingleTickerProviderStateMixin {
  final math.Random _random = math.Random();
  late final Ticker _ticker;
  Offset _offset = Offset.zero;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final intensity = widget.intensity;
    if (intensity <= 0) {
      if (_offset != Offset.zero) {
        setState(() => _offset = Offset.zero);
      }
      _lastElapsed = elapsed;
      return;
    }

    if (elapsed - _lastElapsed < const Duration(milliseconds: 40)) {
      return;
    }
    _lastElapsed = elapsed;

    final maxOffset = 6.0 * intensity;
    final dx = (_random.nextDouble() * 2 - 1) * maxOffset;
    final dy = (_random.nextDouble() * 2 - 1) * maxOffset;
    setState(() => _offset = Offset(dx, dy));
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: _offset,
      child: widget.child,
    );
  }
}

class WindFloat extends StatefulWidget {
  final double intensity;
  final Widget child;

  const WindFloat({
    super.key,
    required this.intensity,
    required this.child,
  });

  @override
  State<WindFloat> createState() => _WindFloatState();
}

class _WindFloatState extends State<WindFloat> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final double _phase;
  late final double _tilt;
  late final double _drift;

  @override
  void initState() {
    super.initState();
    final random = math.Random();
    _phase = random.nextDouble() * math.pi * 2;
    _tilt = (random.nextDouble() * 0.03) - 0.015;
    _drift = 0.6 + random.nextDouble() * 0.6;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 3200 + random.nextInt(1800)),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final intensity = widget.intensity;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = (_controller.value * math.pi * 2 * _drift) + _phase;
        final amplitude = 12.0 * intensity;
        final dx = math.sin(t) * amplitude * 0.7;
        final dy = math.cos(t * 0.9) * amplitude;
        final angle = math.sin(t * 0.7) * _tilt * intensity;
        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.rotate(
            angle: angle,
            child: child,
          ),
        );
      },
    );
  }
}

class ButtonMotion extends StatelessWidget {
  final Widget child;
  final bool enabled;
  final bool applyNoise;
  final bool applyWind;

  const ButtonMotion({
    super.key,
    required this.child,
    this.enabled = true,
    this.applyNoise = true,
    this.applyWind = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final effects = BankEffects.maybeOf(context);
    if (effects == null) return child;

    final windIntensity = effects.windIntensity;
    final shakeIntensity = effects.shakeIntensity;

    Widget current = child;
    if (applyWind && windIntensity > 0) {
      current = WindFloat(intensity: windIntensity, child: current);
    }
    if (applyNoise && shakeIntensity > 0) {
      current = NoiseShake(intensity: shakeIntensity, child: current);
    }
    return current;
  }
}

class WeatherOverlay extends StatefulWidget {
  final _WeatherType type;
  final int windSpeed;
  final Color highlight;
  final Color accent;

  const WeatherOverlay({
    super.key,
    required this.type,
    required this.windSpeed,
    required this.highlight,
    required this.accent,
  });

  @override
  State<WeatherOverlay> createState() => _WeatherOverlayState();
}

class _WeatherOverlayState extends State<WeatherOverlay>
    with SingleTickerProviderStateMixin {
  final List<_WeatherParticle> _particles = [];
  final math.Random _random = math.Random();
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  Size _size = Size.zero;
  double _spawnCarry = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(covariant WeatherOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type) {
      _particles.clear();
      _spawnCarry = 0;
    }
  }

  void _onTick(Duration elapsed) {
    if (widget.type == _WeatherType.none) {
      _lastElapsed = elapsed;
      return;
    }

    final dt = _lastElapsed == Duration.zero
        ? 0.0
        : (elapsed - _lastElapsed).inMilliseconds / 1000.0;
    _lastElapsed = elapsed;
    if (dt <= 0 || _size.isEmpty) return;

    _updateParticles(dt);
    setState(() {});
  }

  void _updateParticles(double dt) {
    final windFactor = (widget.windSpeed / 60).clamp(0.0, 1.0).toDouble();
    final spawnRate = switch (widget.type) {
      _WeatherType.snow => 18 + 18 * windFactor,
      _WeatherType.rain => 80 + 60 * windFactor,
      _WeatherType.wind => windFactor == 0 ? 0 : 10 + 24 * windFactor,
      _WeatherType.none => 0,
    };

    _spawnCarry += spawnRate * dt;
    final spawnCount = _spawnCarry.floor();
    _spawnCarry -= spawnCount;

    for (var i = 0; i < spawnCount; i++) {
      _particles.add(_spawnParticle(windFactor));
    }

    for (var i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt;
      if (p.life <= 0 ||
          p.y > _size.height + 40 ||
          p.x < -80 ||
          p.x > _size.width + 80) {
        _particles.removeAt(i);
      }
    }
  }

  _WeatherParticle _spawnParticle(double windFactor) {
    switch (widget.type) {
      case _WeatherType.snow:
        final size = 2.0 + _random.nextDouble() * 3.5;
        final drift = (windFactor * 40) + (_random.nextDouble() * 30 - 15);
        final fall = 45 + _random.nextDouble() * 50;
        return _WeatherParticle(
          x: _random.nextDouble() * _size.width,
          y: -10,
          vx: drift,
          vy: fall,
          size: size,
          length: size * 2,
          life: 7 + _random.nextDouble() * 5,
        );
      case _WeatherType.rain:
        final slant = (windFactor * 160) - 40;
        return _WeatherParticle(
          x: _random.nextDouble() * _size.width,
          y: -20,
          vx: slant,
          vy: 520 + _random.nextDouble() * 320,
          size: 1.4,
          length: 18 + _random.nextDouble() * 14,
          life: 2.2 + _random.nextDouble(),
        );
      case _WeatherType.wind:
        final speed = 240 + windFactor * 320;
        return _WeatherParticle(
          x: -60,
          y: _random.nextDouble() * _size.height,
          vx: speed,
          vy: _random.nextDouble() * 20 - 10,
          size: 2,
          length: 80 + _random.nextDouble() * 60,
          life: 3.5 + _random.nextDouble(),
        );
      case _WeatherType.none:
        return _WeatherParticle(
          x: 0,
          y: 0,
          vx: 0,
          vy: 0,
          size: 0,
          length: 0,
          life: 0,
        );
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final nextSize = Size(constraints.maxWidth, constraints.maxHeight);
        if (nextSize != _size) {
          _size = nextSize;
        }
        return CustomPaint(
          painter: _WeatherPainter(
            particles: _particles,
            type: widget.type,
            highlight: widget.highlight,
            accent: widget.accent,
          ),
        );
      },
    );
  }
}

class _WeatherParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double length;
  double life;

  _WeatherParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.length,
    required this.life,
  });
}

class _WeatherPainter extends CustomPainter {
  final List<_WeatherParticle> particles;
  final _WeatherType type;
  final Color highlight;
  final Color accent;

  const _WeatherPainter({
    required this.particles,
    required this.type,
    required this.highlight,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (type == _WeatherType.none) return;

    switch (type) {
      case _WeatherType.snow:
        final snowPaint = Paint()..style = PaintingStyle.fill;
        final glowPaint = Paint()..style = PaintingStyle.fill;
        for (final p in particles) {
          final alpha = (p.life / 10).clamp(0.3, 1.0).toDouble();
          snowPaint.color = highlight.withOpacity(alpha);
          glowPaint.color = accent.withOpacity(alpha * 0.4);
          canvas.drawCircle(Offset(p.x, p.y), p.size, glowPaint);
          canvas.drawCircle(Offset(p.x, p.y), p.size * 0.7, snowPaint);
        }
        break;
      case _WeatherType.rain:
        final rainPaint = Paint()
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round;
        for (final p in particles) {
          final alpha = (p.life / 3).clamp(0.3, 0.95).toDouble();
          rainPaint.color = accent.withOpacity(alpha);
          canvas.drawLine(
            Offset(p.x, p.y),
            Offset(p.x + p.vx * 0.08, p.y + p.length),
            rainPaint,
          );
        }
        break;
      case _WeatherType.wind:
        final windPaint = Paint()
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round;
        for (final p in particles) {
          final alpha = (p.life / 4).clamp(0.25, 0.8).toDouble();
          windPaint.color = highlight.withOpacity(alpha);
          canvas.drawLine(
            Offset(p.x, p.y),
            Offset(p.x + p.length, p.y + p.vy * 0.2),
            windPaint,
          );
        }
        break;
      case _WeatherType.none:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherPainter oldDelegate) {
    return true;
  }
}

String _noiseLabel(NoiseLevel noise) {
  switch (noise) {
    case NoiseLevel.quiet:
      return 'Quiet';
    case NoiseLevel.low:
      return 'Low';
    case NoiseLevel.med:
      return 'Medium';
    case NoiseLevel.high:
      return 'Loud';
    case NoiseLevel.boomBoom:
      return 'Boom';
  }
}

int _noiseToDb(NoiseLevel noise) {
  switch (noise) {
    case NoiseLevel.quiet:
      return 40;
    case NoiseLevel.low:
      return 55;
    case NoiseLevel.med:
      return 70;
    case NoiseLevel.high:
      return 78;
    case NoiseLevel.boomBoom:
      return 85;
  }
}

double _shakeIntensityFromDb(double db) {
  if (db < 70) return 0;
  const minDb = 70.0;
  const maxDb = 85.0;
  final maxRatio = math.pow(10, (maxDb - minDb) / 20).toDouble() - 1;
  final ratio = math.pow(10, (db - minDb) / 20).toDouble() - 1;
  final normalized = ratio / maxRatio;
  return normalized.clamp(0.0, 1.0).toDouble();
}

double _windIntensityFromSpeed({
  required int windSpeed,
  required Region region,
}) {
  if (region != Region.windyPlains) return 0;
  return (windSpeed / 60).clamp(0.0, 1.0).toDouble();
}

IconData _temperatureIcon(int temperature) {
  if (temperature <= 0) return Icons.ac_unit_rounded;
  if (temperature <= 15) return Icons.cloud_rounded;
  if (temperature <= 28) return Icons.thermostat_rounded;
  return Icons.wb_sunny_rounded;
}

IconData _noiseIcon(NoiseLevel noise) {
  switch (noise) {
    case NoiseLevel.quiet:
      return Icons.volume_off_rounded;
    case NoiseLevel.low:
      return Icons.volume_down_rounded;
    case NoiseLevel.med:
      return Icons.volume_up_rounded;
    case NoiseLevel.high:
      return Icons.volume_up_rounded;
    case NoiseLevel.boomBoom:
      return Icons.music_note_rounded;
  }
}

class EnvironmentDashboard extends StatelessWidget {
  final Environment? environment;

  const EnvironmentDashboard({super.key, required this.environment});

  @override
  Widget build(BuildContext context) {
    final colors = BankTheme.of(context);
    final env = environment;

    if (env == null) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: const [
          _DashboardChip.placeholder(),
          _DashboardChip.placeholder(),
          _DashboardChip.placeholder(),
        ],
      );
    }

    final items = [
      _DashboardChipData(Icons.public_rounded, env.region.label),
      _DashboardChipData(_temperatureIcon(env.temperature), '${env.temperature}°C'),
      _DashboardChipData(Icons.water_drop_rounded, '${env.humidity}%'),
      _DashboardChipData(Icons.air_rounded, '${env.windSpeed} km/h'),
      _DashboardChipData(Icons.brightness_6_rounded, '${env.brightness}/10'),
      _DashboardChipData(_noiseIcon(env.noise), _noiseLabel(env.noise)),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (item) => ButtonMotion(
              child: _DashboardChip(
                icon: item.icon,
                label: item.label,
                background: colors.surface.withAlpha(235),
                borderColor: colors.divider,
                textColor: colors.text,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _DashboardChipData {
  final IconData icon;
  final String label;

  const _DashboardChipData(this.icon, this.label);
}

class _DashboardChip extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final Color? background;
  final Color? borderColor;
  final Color? textColor;
  final bool placeholder;

  const _DashboardChip({
    required this.icon,
    required this.label,
    required this.background,
    required this.borderColor,
    required this.textColor,
  }) : placeholder = false;

  const _DashboardChip.placeholder()
      : icon = null,
        label = null,
        background = null,
        borderColor = null,
        textColor = null,
        placeholder = true;

  @override
  Widget build(BuildContext context) {
    final colors = BankTheme.of(context);
    final bg = background ?? colors.surface.withAlpha(230);
    final border = borderColor ?? colors.divider;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: placeholder
          ? Container(
              width: 64,
              height: 12,
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(6),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: textColor),
                const SizedBox(width: 6),
                Text(
                  label ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
    );
  }
}

class HomeAccountsPage extends StatefulWidget {
  final String? userId;

  const HomeAccountsPage({super.key, this.userId});

  @override
  State<HomeAccountsPage> createState() => _HomeAccountsPageState();
}

class _HomeAccountsPageState extends State<HomeAccountsPage> {
  late Future<Environment> _environmentFuture;
  late Future<List<Account>> _accountsFuture;
  double _peakDb = 0;
  Timer? _environmentTimer;
  Environment? _liveEnvironment; // For Socket.IO updates
  DateTime? _lastEnvironmentUpdate;
  static const Duration _environmentThrottle = Duration(milliseconds: 400);

  bool get _useBackend => widget.userId != null;

  @override
  void initState() {
    super.initState();
    _initData();

    // Set up Socket.IO environment listener if using backend
    if (_useBackend) {
      BackendService.connect(
        userId: widget.userId!,
        onEnvironmentUpdate: _onEnvironmentUpdate,
        onGoldUpdate: _onGoldUpdate,
      );
    }

    // Fallback polling for environment (less frequent if using Socket.IO)
    _environmentTimer = Timer.periodic(
      Duration(seconds: _useBackend ? 5 : 1),
      (_) => _refreshEnvironment(),
    );

    // Listen for voice command refresh notifications
    AccountRefreshNotifier.instance.addListener(_onVoiceCommandRefresh);
  }

  void _onVoiceCommandRefresh() {
    if (!mounted) return;
    debugPrint('Voice command completed - refreshing accounts');
    _refreshAccounts();
  }

  void _initData() {
    if (_useBackend) {
      _environmentFuture = _fetchBackendEnvironment();
      _accountsFuture = BackendService.getAccounts(widget.userId!);
    } else {
      _environmentFuture = Api.getEnvironment().then(_recordPeakDb);
      _accountsFuture = Api.getAccounts();
    }
  }

  Future<Environment> _fetchBackendEnvironment() async {
    final env = await BackendService.getEnvironment();
    if (env != null) {
      return _recordPeakDb(env);
    }
    // Fallback to mock if backend fails
    return Api.getEnvironment().then(_recordPeakDb);
  }

  void _onEnvironmentUpdate(Environment env) {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      return;
    }
    final now = DateTime.now();
    if (_lastEnvironmentUpdate != null &&
        now.difference(_lastEnvironmentUpdate!) < _environmentThrottle) {
      return;
    }
    if (_liveEnvironment != null && _isSameEnvironment(_liveEnvironment!, env)) {
      return;
    }
    setState(() {
      _liveEnvironment = env;
      _recordPeakDb(env);
    });
    _lastEnvironmentUpdate = now;
  }

  bool _isSameEnvironment(Environment a, Environment b) {
    return a.region == b.region &&
        a.temperature == b.temperature &&
        a.humidity == b.humidity &&
        a.windSpeed == b.windSpeed &&
        a.brightness == b.brightness &&
        a.noise == b.noise;
  }

  void _onGoldUpdate() {
    if (!mounted) return;
    _refreshAccounts();
  }

  Environment _recordPeakDb(Environment env) {
    _peakDb = _noiseToDb(env.noise).toDouble();
    return env;
  }

  Future<void> _refreshAccounts() async {
    setState(() {
      if (_useBackend) {
        _accountsFuture = BackendService.getAccounts(widget.userId!);
      } else {
        _accountsFuture = Api.getAccounts();
      }
    });
  }

  void _refreshEnvironment() {
    if (!mounted) return;
    // Skip refresh if we have live Socket.IO updates
    if (_useBackend && _liveEnvironment != null) return;

    setState(() {
      if (_useBackend) {
        _environmentFuture = _fetchBackendEnvironment();
      } else {
        _environmentFuture = Api.getEnvironment().then(_recordPeakDb);
      }
    });
  }

  @override
  void dispose() {
    _environmentTimer?.cancel();
    AccountRefreshNotifier.instance.removeListener(_onVoiceCommandRefresh);
    super.dispose();
  }

  Future<void> _openAccount(Account account) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AccountDetailPage(
          account: account,
          userId: widget.userId,
        ),
      ),
    );
    await _refreshAccounts();
  }

  Future<void> _openDebugMenu(BuildContext parentContext, Environment current) async {
    final patch = DebugOverrides()
      ..region = Api.debug.region ?? current.region
      ..temperature = Api.debug.temperature ?? current.temperature
      ..humidity = Api.debug.humidity ?? current.humidity
      ..windSpeed = Api.debug.windSpeed ?? current.windSpeed
      ..brightness = Api.debug.brightness ?? current.brightness
      ..noise = Api.debug.noise ?? current.noise;

    await showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Widget sectionTitle(String text) => Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 6),
                  child: Text(
                    text,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                );

            Widget sliderField({
              required String label,
              required int min,
              required int max,
              required int value,
              required void Function(int) onChanged,
            }) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$label: $value'),
                  Slider(
                    value: value.toDouble(),
                    min: min.toDouble(),
                    max: max.toDouble(),
                    divisions: max - min,
                    onChanged: (val) => setLocal(() => onChanged(val.round())),
                  ),
                ],
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
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
                            'Debug Environment',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ),
                        ButtonMotion(
                          child: TextButton(
                            onPressed: () {
                              Api.debug.clear();
                              _refreshEnvironment();
                              Navigator.of(ctx).pop();
                            },
                            child: const Text('Clear'),
                          ),
                        ),
                      ],
                    ),
                    sectionTitle('Region'),
                    DropdownButtonFormField<Region>(
                      initialValue: patch.region ?? Region.darkCave,
                      items: Region.values
                          .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                          .toList(),
                      onChanged: (value) =>
                          setLocal(() => patch.region = value ?? patch.region),
                    ),
                    sectionTitle('Temperature'),
                    sliderField(
                      label: 'Temperature (°C)',
                      min: -30,
                      max: 50,
                      value: patch.temperature ?? current.temperature,
                      onChanged: (value) => patch.temperature = value,
                    ),
                    sectionTitle('Humidity'),
                    sliderField(
                      label: 'Humidity (%)',
                      min: 0,
                      max: 100,
                      value: patch.humidity ?? current.humidity,
                      onChanged: (value) => patch.humidity = value,
                    ),
                    sectionTitle('Wind'),
                    sliderField(
                      label: 'Wind Speed',
                      min: 0,
                      max: 60,
                      value: patch.windSpeed ?? current.windSpeed,
                      onChanged: (value) => patch.windSpeed = value,
                    ),
                    sectionTitle('Brightness'),
                    sliderField(
                      label: 'Brightness (1-10)',
                      min: 1,
                      max: 10,
                      value: patch.brightness ?? current.brightness,
                      onChanged: (value) => patch.brightness = value,
                    ),
                    sectionTitle('Noise'),
                    DropdownButtonFormField<NoiseLevel>(
                      initialValue: patch.noise ?? current.noise,
                      items: NoiseLevel.values
                          .map((n) => DropdownMenuItem(value: n, child: Text(n.name)))
                          .toList(),
                      onChanged: (value) =>
                          setLocal(() => patch.noise = value ?? patch.noise),
                    ),
                    const SizedBox(height: 16),
                    ButtonMotion(
                      child: FilledButton(
                        onPressed: () {
                          Api.debug
                            ..region = patch.region
                            ..temperature = patch.temperature
                            ..humidity = patch.humidity
                            ..windSpeed = patch.windSpeed
                            ..brightness = patch.brightness
                            ..noise = patch.noise;
                          _refreshEnvironment();
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Apply'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ButtonMotion(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final headerHeight = _headerHeight(context, 0.32, min: 220, max: 320);

    return FutureBuilder<Environment>(
      future: _environmentFuture,
      builder: (context, snapshot) {
        // Prefer live Socket.IO environment over future data
        final environment = _liveEnvironment ?? snapshot.data;
        final region = environment?.region ?? Region.darkCave;
        final colors = BankColors.forEnvironment(
          region: region,
          temperature: environment?.temperature,
          humidity: environment?.humidity,
          brightness: environment?.brightness,
        );
        final shakeIntensity = _shakeIntensityFromDb(_peakDb);
        final windSpeed = environment?.windSpeed ?? 0;
        final windIntensity = _windIntensityFromSpeed(
          windSpeed: windSpeed,
          region: region,
        );
        final weather = _weatherForRegion(region);
        final weatherPalette = _weatherPalette(region, colors);

        return BankTheme(
          colors: colors,
          child: BankEffects(
            environment: environment,
            windIntensity: windIntensity,
            shakeIntensity: shakeIntensity,
            child: Theme(
              data: _buildTheme(colors),
              child: PageEntrance(
                child: Stack(
                  children: [
                    Scaffold(
                      body: Column(
                        children: [
                          RegionHeader(
                            region: region,
                            height: headerHeight,
                            child: Stack(
                              children: [
                                Align(
                                  alignment: Alignment.topRight,
                                  child: ButtonMotion(
                                    enabled: environment != null,
                                    child: IconButton(
                                      icon: const Icon(Icons.tune_rounded),
                                      tooltip: 'Debug',
                                      onPressed: environment == null
                                          ? null
                                          : () => _openDebugMenu(context, environment),
                                    ),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.bottomLeft,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      EnvironmentDashboard(
                                        environment: environment,
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Good Morning',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'The Gardens',
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: SafeArea(
                              top: false,
                              child: Container(
                                color: colors.surface,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 16),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 16),
                                      child: SectionTitle('Accounts'),
                                    ),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: FutureBuilder<List<Account>>(
                                        future: _accountsFuture,
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState !=
                                              ConnectionState.done) {
                                            return const Center(
                                              child: CircularProgressIndicator(),
                                            );
                                          }

                                          final accounts =
                                              snapshot.data ?? const <Account>[];
                                          if (accounts.isEmpty) {
                                            return const Center(
                                              child: Text('No accounts found.'),
                                            );
                                          }

                                          return ListView.separated(
                                            padding: const EdgeInsets.fromLTRB(
                                                16, 0, 16, 20),
                                            itemCount: accounts.length,
                                            separatorBuilder: (_, __) =>
                                                const SizedBox(height: 12),
                                            itemBuilder: (context, index) {
                                              final account = accounts[index];
                                              return AccountCard(
                                                account: account,
                                                onTap: () => _openAccount(account),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (weather != _WeatherType.none)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: WeatherOverlay(
                            type: weather,
                            windSpeed: windSpeed,
                            highlight: weatherPalette.highlight,
                            accent: weatherPalette.accent,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AccountDetailPage extends StatefulWidget {
  final Account account;
  final String? userId;

  const AccountDetailPage({
    super.key,
    required this.account,
    this.userId,
  });

  @override
  State<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends State<AccountDetailPage> {
  late Future<Environment> _environmentFuture;
  late Future<Account> _accountFuture;
  late Future<List<TransactionEntry>> _transactionsFuture;
  double _peakDb = 0;
  Timer? _environmentTimer;

  bool get _useBackend => widget.userId != null;

  @override
  void initState() {
    super.initState();
    if (_useBackend) {
      _environmentFuture = _fetchBackendEnvironment();
    } else {
      _environmentFuture = Api.getEnvironment().then(_recordPeakDb);
    }
    _environmentTimer = Timer.periodic(
      Duration(seconds: _useBackend ? 5 : 1),
      (_) => _refreshEnvironment(),
    );
    _refresh();
  }

  Future<Environment> _fetchBackendEnvironment() async {
    final env = await BackendService.getEnvironment();
    if (env != null) {
      return _recordPeakDb(env);
    }
    return Api.getEnvironment().then(_recordPeakDb);
  }

  Environment _recordPeakDb(Environment env) {
    _peakDb = _noiseToDb(env.noise).toDouble();
    return env;
  }

  void _refresh() {
    if (_useBackend) {
      // Use backend - account.id is the integer ID from backend
      _accountFuture = Future.value(widget.account);
      _transactionsFuture = BackendService.getAccountTransactions(
        widget.account.id,
        isLoan: widget.account.isLoan,
      );
    } else {
      _accountFuture = Api.getAccount(widget.account.id);
      _transactionsFuture = Api.getTransactions(widget.account.id);
    }
  }

  void _refreshEnvironment() {
    if (!mounted) return;
    setState(() {
      if (_useBackend) {
        _environmentFuture = _fetchBackendEnvironment();
      } else {
        _environmentFuture = Api.getEnvironment().then(_recordPeakDb);
      }
    });
  }

  Future<void> _openAction(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    setState(_refresh);
  }

  @override
  void dispose() {
    _environmentTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final headerHeight = _headerHeight(context, 0.2, min: 160, max: 220);

    return FutureBuilder<Environment>(
      future: _environmentFuture,
      builder: (context, snapshot) {
        final environment = snapshot.data;
        final region = environment?.region ?? Region.darkCave;
        final colors = BankColors.forEnvironment(
          region: region,
          temperature: environment?.temperature,
          humidity: environment?.humidity,
          brightness: environment?.brightness,
        );
        final shakeIntensity = _shakeIntensityFromDb(_peakDb);
        final windSpeed = environment?.windSpeed ?? 0;
        final windIntensity = _windIntensityFromSpeed(
          windSpeed: windSpeed,
          region: region,
        );
        final weather = _weatherForRegion(region);
        final weatherPalette = _weatherPalette(region, colors);

        return BankTheme(
          colors: colors,
          child: BankEffects(
            environment: environment,
            windIntensity: windIntensity,
            shakeIntensity: shakeIntensity,
            child: Theme(
              data: _buildTheme(colors),
              child: PageEntrance(
                child: Stack(
                  children: [
                    Scaffold(
                      body: Column(
                        children: [
                          RegionHeader(
                            region: region,
                            height: headerHeight,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                ButtonMotion(
                                  child: IconButton(
                                    icon: const Icon(Icons.arrow_back_rounded),
                                    onPressed: () => Navigator.of(context).pop(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: SafeArea(
                              top: false,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 16),
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 16),
                                    child: FutureBuilder<Account>(
                                      future: _accountFuture,
                                      builder: (context, accountSnapshot) {
                                        final account =
                                            accountSnapshot.data ?? widget.account;
                                        return Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: colors.surface,
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            border:
                                                Border.all(color: colors.divider),
                                            boxShadow: [
                                              BoxShadow(
                                                color: colors.shadow,
                                                blurRadius: 12,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      account.name,
                                                      style: const TextStyle(
                                                        fontSize: 20,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      _formatBalance(
                                                        account.balance,
                                                      ),
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w600,
                                                        color: colors.textMuted,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              SizedBox(
                                                width: 140,
                                                height: 64,
                                                child: FutureBuilder<
                                                    List<TransactionEntry>>(
                                                  future: _transactionsFuture,
                                                  builder: (context, txSnapshot) {
                                                    return BalanceSparkline(
                                                      currentBalance:
                                                          account.balance,
                                                      transactions:
                                                          txSnapshot.data ??
                                                              const <TransactionEntry>[],
                                                      placeholder:
                                                          txSnapshot.connectionState !=
                                                              ConnectionState.done,
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 16),
                                    child: Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        if (!widget.account.isLoan)
                                          PillButton(
                                            label: 'Transfer',
                                            icon: Icons.swap_horiz_rounded,
                                            onPressed: () => _openAction(
                                              TransferPage(
                                                account: widget.account,
                                                userId: widget.userId,
                                              ),
                                            ),
                                          ),
                                        if (!widget.account.isLoan)
                                          PillButton(
                                            label: 'Send',
                                            icon: Icons.send_rounded,
                                            onPressed: () => _openAction(
                                              SendPage(
                                                account: widget.account,
                                                userId: widget.userId,
                                              ),
                                            ),
                                          ),
                                        PillButton(
                                          label: 'Pay',
                                          icon: Icons.receipt_long_rounded,
                                          onPressed: () => _openAction(
                                            PayPage(
                                              account: widget.account,
                                              userId: widget.userId,
                                            ),
                                          ),
                                        ),
                                        // Gold exchange button for treasure chest
                                        if (widget.account.type == 'treasure_chest' && widget.userId != null)
                                          PillButton(
                                            label: 'Exchange',
                                            icon: Icons.currency_exchange,
                                            onPressed: () => _openAction(
                                              GoldExchangePage(
                                                treasureAccount: widget.account,
                                                userId: widget.userId!,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (widget.account.isLoan)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 8, 16, 0),
                                      child: Text(
                                        'Loan accounts can receive transfers and pay bills only.',
                                        style: TextStyle(
                                          color: colors.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 18),
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 16),
                                    child: SectionTitle('History'),
                                  ),
                                  const SizedBox(height: 10),
                                  Expanded(
                                    child: FutureBuilder<List<TransactionEntry>>(
                                      future: _transactionsFuture,
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState !=
                                            ConnectionState.done) {
                                          return const Center(
                                            child: CircularProgressIndicator(),
                                          );
                                        }
                                        final items = snapshot.data ??
                                            const <TransactionEntry>[];
                                        if (items.isEmpty) {
                                          return const Center(
                                            child: Text('No transactions yet.'),
                                          );
                                        }
                                        return ListView.separated(
                                          padding: const EdgeInsets.fromLTRB(
                                              16, 0, 16, 20),
                                          itemCount: items.length,
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(height: 10),
                                          itemBuilder: (context, index) {
                                            return TransactionRow(
                                              entry: items[index],
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (weather != _WeatherType.none)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: WeatherOverlay(
                            type: weather,
                            windSpeed: windSpeed,
                            highlight: weatherPalette.highlight,
                            accent: weatherPalette.accent,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

enum RecipientType { account, user, payee }

Future<void> _submitTransfer({
  required String fromAccountId,
  required String toId,
  required int amount,
  String? userId,
}) async {
  if (userId != null) {
    // Use backend
    final fromId = int.tryParse(fromAccountId);
    final toIdInt = int.tryParse(toId);
    if (fromId != null && toIdInt != null) {
      await BackendService.transfer(
        fromAccountId: fromId,
        toAccountId: toIdInt,
        amount: amount.toDouble(),
      );
    }
  } else {
    // Use mock API
    await Api.transfer(
      fromAccountId: fromAccountId,
      toAccountId: toId,
      amount: amount,
    );
  }
}

Future<void> _submitSend({
  required String fromAccountId,
  required String toId,
  required int amount,
  String? userId,
}) async {
  if (userId != null) {
    // Use backend - send money to another user
    await BackendService.sendMoney(
      fromUserId: userId,
      toUserId: toId,
      amount: amount.toDouble(),
    );
  } else {
    await Api.send(
      fromAccountId: fromAccountId,
      toUserId: toId,
      amount: amount,
    );
  }
}

Future<void> _submitPay({
  required String fromAccountId,
  required String toId,
  required int amount,
  String? userId,
}) async {
  // Pay functionality - for now just use mock API
  // Backend doesn't have payee concept yet
  await Api.pay(
    fromAccountId: fromAccountId,
    toPayeeId: toId,
    amount: amount,
  );
}

class TransferPage extends StatelessWidget {
  final Account? account;
  final String? userId;

  const TransferPage({
    super.key,
    this.account,
    this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return MoneyActionPage(
      title: 'Transfer',
      submitLabel: 'Continue',
      fromAccount: account,
      recipientType: RecipientType.account,
      toLabel: 'To',
      onSubmit: _submitTransfer,
      userId: userId,
    );
  }
}

class SendPage extends StatelessWidget {
  final Account? account;
  final String? userId;

  const SendPage({
    super.key,
    this.account,
    this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return MoneyActionPage(
      title: 'Send',
      submitLabel: 'Continue',
      fromAccount: account,
      recipientType: RecipientType.user,
      toLabel: 'To',
      onSubmit: _submitSend,
      userId: userId,
    );
  }
}

class PayPage extends StatelessWidget {
  final Account? account;
  final String? userId;

  const PayPage({
    super.key,
    this.account,
    this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return MoneyActionPage(
      title: 'Pay Bill',
      submitLabel: 'Pay',
      fromAccount: account,
      recipientType: RecipientType.payee,
      toLabel: 'Payee',
      onSubmit: _submitPay,
      userId: userId,
    );
  }
}

class GoldExchangePage extends StatefulWidget {
  final Account treasureAccount;
  final String userId;

  const GoldExchangePage({
    super.key,
    required this.treasureAccount,
    required this.userId,
  });

  @override
  State<GoldExchangePage> createState() => _GoldExchangePageState();
}

class _GoldExchangePageState extends State<GoldExchangePage> {
  int _barsToExchange = 1;
  String _destinationType = 'checking';
  bool _isLoading = false;
  int _goldRate = 7000;
  late Future<List<Account>> _accountsFuture;

  @override
  void initState() {
    super.initState();
    _loadGoldRate();
    _accountsFuture = BackendService.getAccounts(widget.userId);
  }

  Future<void> _loadGoldRate() async {
    final rate = await BackendService.getGoldRate();
    if (mounted) {
      setState(() => _goldRate = rate);
    }
  }

  int get _maxBars => widget.treasureAccount.balance;
  int get _cashValue => _barsToExchange * _goldRate;

  Future<void> _exchange() async {
    if (_barsToExchange <= 0 || _barsToExchange > _maxBars) return;

    setState(() => _isLoading = true);

    final result = await BackendService.exchangeGold(
      userId: widget.userId,
      bars: _barsToExchange,
      toAccountType: _destinationType,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Exchanged $_barsToExchange gold bar${_barsToExchange > 1 ? 's' : ''} for \$${_cashValue.toStringAsFixed(0)}!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exchange failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = BankTheme.of(context);

    return PageEntrance(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Exchange Gold'),
          backgroundColor: colors.surface,
          foregroundColor: colors.text,
          elevation: 0,
        ),
        backgroundColor: colors.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // Gold balance card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade600, Colors.amber.shade800],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.savings, color: Colors.white, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      '${widget.treasureAccount.balance} Gold Bars',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rate: \$$_goldRate per bar',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Bars to exchange
              Text(
                'Bars to Exchange',
                style: TextStyle(
                  color: colors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    onPressed: _barsToExchange > 1
                        ? () => setState(() => _barsToExchange--)
                        : null,
                    icon: Icon(Icons.remove_circle, color: colors.text),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.divider),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_barsToExchange',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _barsToExchange < _maxBars
                        ? () => setState(() => _barsToExchange++)
                        : null,
                    icon: Icon(Icons.add_circle, color: colors.text),
                  ),
                ],
              ),
              if (_maxBars > 1) ...[
                const SizedBox(height: 8),
                Slider(
                  value: _barsToExchange.toDouble(),
                  min: 1,
                  max: _maxBars.toDouble(),
                  divisions: _maxBars > 1 ? _maxBars - 1 : 1,
                  onChanged: (v) => setState(() => _barsToExchange = v.round()),
                ),
              ],
              const SizedBox(height: 24),

              // Destination account
              Text(
                'Deposit To',
                style: TextStyle(
                  color: colors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<Account>>(
                future: _accountsFuture,
                builder: (context, snapshot) {
                  final accounts = snapshot.data ?? [];
                  final validAccounts = accounts
                      .where((a) => a.type == 'checking' || a.type == 'savings')
                      .toList();

                  return Wrap(
                    spacing: 12,
                    children: validAccounts.map((account) {
                      final isSelected = _destinationType == account.type;
                      return ChoiceChip(
                        label: Text(account.name),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() => _destinationType = account.type ?? 'checking');
                        },
                        selectedColor: colors.text.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: isSelected ? colors.text : colors.textMuted,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const Spacer(),

              // Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'You will receive',
                      style: TextStyle(color: colors.textMuted, fontSize: 16),
                    ),
                    Text(
                      '\$${_cashValue.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Exchange button
              ElevatedButton(
                onPressed: _isLoading || _maxBars == 0 ? null : _exchange,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _maxBars == 0 ? 'No Gold to Exchange' : 'Exchange Gold',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

typedef PaymentSubmit = Future<void> Function({
  required String fromAccountId,
  required String toId,
  required int amount,
  String? userId,
});

class MoneyActionPage extends StatefulWidget {
  final String title;
  final String submitLabel;
  final Account? fromAccount;
  final RecipientType recipientType;
  final String toLabel;
  final PaymentSubmit onSubmit;
  final String? userId;

  const MoneyActionPage({
    super.key,
    required this.title,
    required this.submitLabel,
    required this.fromAccount,
    required this.recipientType,
    required this.toLabel,
    required this.onSubmit,
    this.userId,
  });

  @override
  State<MoneyActionPage> createState() => _MoneyActionPageState();
}

class _MoneyActionPageState extends State<MoneyActionPage> {
  late Future<Environment> _environmentFuture;
  late Future<List<Account>> _accountsFuture;
  Future<List<UserProfile>>? _usersFuture;
  Future<List<Payee>>? _payeesFuture;
  final TextEditingController _amountController = TextEditingController();

  String? _fromAccountId;
  String? _toId;
  bool _submitting = false;
  double _peakDb = 0;
  Timer? _environmentTimer;

  bool get _useBackend => widget.userId != null;

  @override
  void initState() {
    super.initState();
    if (_useBackend) {
      _environmentFuture = _fetchBackendEnvironment();
      _accountsFuture = BackendService.getAccounts(widget.userId!);
    } else {
      _environmentFuture = Api.getEnvironment().then(_recordPeakDb);
      _accountsFuture = Api.getAccounts();
    }
    _environmentTimer = Timer.periodic(
      Duration(seconds: _useBackend ? 5 : 1),
      (_) => _refreshEnvironment(),
    );
    if (widget.recipientType == RecipientType.user) {
      if (_useBackend) {
        _usersFuture = BackendService.findUsers('');
      } else {
        _usersFuture = Api.getUsers();
      }
    }
    if (widget.recipientType == RecipientType.payee) {
      _payeesFuture = Api.getPayees();
    }
    _fromAccountId = widget.fromAccount?.id;
  }

  Future<Environment> _fetchBackendEnvironment() async {
    final env = await BackendService.getEnvironment();
    if (env != null) {
      return _recordPeakDb(env);
    }
    return Api.getEnvironment().then(_recordPeakDb);
  }

  Environment _recordPeakDb(Environment env) {
    _peakDb = _noiseToDb(env.noise).toDouble();
    return env;
  }

  void _refreshEnvironment() {
    if (!mounted) return;
    setState(() {
      if (_useBackend) {
        _environmentFuture = _fetchBackendEnvironment();
      } else {
        _environmentFuture = Api.getEnvironment().then(_recordPeakDb);
      }
    });
  }

  @override
  void dispose() {
    _environmentTimer?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  void _ensureDefaultFrom(List<Account> accounts) {
    if (accounts.isEmpty) return;
    if (_fromAccountId != null &&
        accounts.any((account) => account.id == _fromAccountId)) {
      return;
    }
    String fallback = accounts.first.id;
    for (final account in accounts) {
      final name = account.name.toLowerCase();
      if (name.contains('checking') || name.contains('chequing')) {
        fallback = account.id;
        break;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _fromAccountId != null) return;
      setState(() => _fromAccountId = fallback);
    });
  }

  void _ensureValidTo(List<String> validIds) {
    if (_toId == null || validIds.contains(_toId)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _toId = null);
    });
  }

  List<Account> _availableToAccounts(List<Account> accounts) {
    final fromId = _fromAccountId;
    if (fromId == null) return accounts;
    return accounts.where((account) => account.id != fromId).toList();
  }

  List<Account> _eligibleFromAccounts(List<Account> accounts) {
    if (widget.recipientType == RecipientType.payee) {
      return accounts;
    }
    return accounts.where((account) => !account.isLoan).toList();
  }

  Widget _buildToField() {
    switch (widget.recipientType) {
      case RecipientType.account:
        return FutureBuilder<List<Account>>(
          future: _accountsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final accounts = snapshot.data ?? const <Account>[];
            final available = _availableToAccounts(accounts);
            _ensureValidTo(available.map((account) => account.id).toList());
            final selectedTo =
                available.any((account) => account.id == _toId) ? _toId : null;

            if (available.isEmpty) {
              return Text(
                'No destination accounts available.',
                style: TextStyle(color: BankTheme.of(context).textMuted),
              );
            }

            return DropdownButtonFormField<String>(
              key: ValueKey('to-${selectedTo ?? 'none'}'),
              initialValue: selectedTo,
              isExpanded: true,
              icon: const Icon(Icons.expand_more_rounded),
              decoration: const InputDecoration(),
              items: available
                  .map(
                    (account) => DropdownMenuItem(
                      value: account.id,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              account.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(_formatAmount(account.balance)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => _toId = value);
              },
            );
          },
        );
      case RecipientType.user:
        final future = _usersFuture;
        return FutureBuilder<List<UserProfile>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final users = snapshot.data ?? const <UserProfile>[];
            _ensureValidTo(users.map((user) => user.id).toList());
            final selectedUser =
                users.any((user) => user.id == _toId) ? _toId : null;
            return DropdownButtonFormField<String>(
              key: ValueKey('to-${selectedUser ?? 'none'}'),
              initialValue: selectedUser,
              isExpanded: true,
              icon: const Icon(Icons.expand_more_rounded),
              decoration: const InputDecoration(),
              items: users
                  .map(
                    (user) => DropdownMenuItem(
                      value: user.id,
                      child: Text(user.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => _toId = value);
              },
            );
          },
        );
      case RecipientType.payee:
        final future = _payeesFuture;
        return FutureBuilder<List<Payee>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final payees = snapshot.data ?? const <Payee>[];
            _ensureValidTo(payees.map((payee) => payee.id).toList());
            final selectedPayee =
                payees.any((payee) => payee.id == _toId) ? _toId : null;
            return DropdownButtonFormField<String>(
              key: ValueKey('to-${selectedPayee ?? 'none'}'),
              initialValue: selectedPayee,
              isExpanded: true,
              icon: const Icon(Icons.expand_more_rounded),
              decoration: const InputDecoration(),
              items: payees
                  .map(
                    (payee) => DropdownMenuItem(
                      value: payee.id,
                      child: Text(payee.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => _toId = value);
              },
            );
          },
        );
    }
  }

  Future<void> _submit() async {
    final fromId = _fromAccountId;
    final toId = _toId;
    final raw = _amountController.text.trim();
    final cleaned = raw.replaceAll(RegExp(r'[^0-9\.]'), '');
    final parsed = double.tryParse(cleaned);
    final amount = parsed == null ? 0 : parsed.round();

    if (fromId == null || toId == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select accounts and enter a valid amount.'),
          duration: Duration(milliseconds: 900),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    await widget.onSubmit(
      fromAccountId: fromId,
      toId: toId,
      amount: amount,
      userId: widget.userId,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final headerHeight = _headerHeight(context, 0.2, min: 160, max: 220);

    return FutureBuilder<Environment>(
      future: _environmentFuture,
      builder: (context, snapshot) {
        final environment = snapshot.data;
        final region = environment?.region ?? Region.darkCave;
        final colors = BankColors.forEnvironment(
          region: region,
          temperature: environment?.temperature,
          humidity: environment?.humidity,
          brightness: environment?.brightness,
        );
        final shakeIntensity = _shakeIntensityFromDb(_peakDb);
        final windSpeed = environment?.windSpeed ?? 0;
        final windIntensity = _windIntensityFromSpeed(
          windSpeed: windSpeed,
          region: region,
        );
        final weather = _weatherForRegion(region);
        final weatherPalette = _weatherPalette(region, colors);

        return BankTheme(
          colors: colors,
          child: BankEffects(
            environment: environment,
            windIntensity: windIntensity,
            shakeIntensity: shakeIntensity,
            child: Theme(
              data: _buildTheme(colors),
              child: PageEntrance(
                child: Stack(
                  children: [
                    Scaffold(
                      body: Column(
                        children: [
                          RegionHeader(
                            region: region,
                            height: headerHeight,
                            child: Row(
                              children: [
                                ButtonMotion(
                                  child: IconButton(
                                    icon: const Icon(Icons.arrow_back_rounded),
                                    onPressed: () => Navigator.of(context).pop(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: SafeArea(
                              top: false,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: ListView(
                                      padding:
                                          const EdgeInsets.fromLTRB(16, 16, 16, 12),
                                      children: [
                                        SectionTitle(widget.title),
                                        const SizedBox(height: 12),
                                        FieldLabel('From'),
                                        FutureBuilder<List<Account>>(
                                          future: _accountsFuture,
                                          builder: (context, snapshot) {
                                            if (snapshot.connectionState !=
                                                ConnectionState.done) {
                                              return const Padding(
                                                padding: EdgeInsets.symmetric(
                                                    vertical: 18),
                                                child: Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                ),
                                              );
                                            }
                                            final accounts =
                                                snapshot.data ?? const <Account>[];
                                            final eligible =
                                                _eligibleFromAccounts(accounts);
                                            _ensureDefaultFrom(eligible);
                                            final selectedFrom = eligible.any(
                                                    (account) =>
                                                        account.id ==
                                                        _fromAccountId)
                                                ? _fromAccountId
                                                : null;
                                            if (eligible.isEmpty) {
                                              return Text(
                                                'No eligible source accounts.',
                                                style: TextStyle(
                                                  color: BankTheme.of(context)
                                                      .textMuted,
                                                ),
                                              );
                                            }
                                            return DropdownButtonFormField<String>(
                                              key: ValueKey(
                                                'from-${selectedFrom ?? 'none'}',
                                              ),
                                              initialValue: selectedFrom,
                                              isExpanded: true,
                                              icon: const Icon(
                                                Icons.expand_more_rounded,
                                              ),
                                              decoration: const InputDecoration(),
                                              items: eligible
                                                  .map(
                                                    (account) => DropdownMenuItem(
                                                      value: account.id,
                                                      child: Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              account.name,
                                                              overflow: TextOverflow
                                                                  .ellipsis,
                                                            ),
                                                          ),
                                                          Text(
                                                            _formatAmount(
                                                              account.balance,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                              onChanged: (value) {
                                                setState(() {
                                                  _fromAccountId = value;
                                                  if (value != null &&
                                                      value == _toId) {
                                                    _toId = null;
                                                  }
                                                });
                                              },
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        FieldLabel('Amount'),
                                        TextField(
                                          controller: _amountController,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(
                                            decimal: true,
                                          ),
                                          decoration: const InputDecoration(
                                            hintText: 'Amount 0.00\$',
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        FieldLabel(widget.toLabel),
                                        _buildToField(),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(16, 0, 16, 20),
                                    child: PillButton(
                                      label: _submitting
                                          ? 'Working...'
                                          : widget.submitLabel,
                                      onPressed: _submitting ? null : _submit,
                                      fullWidth: true,
                                      primary: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (weather != _WeatherType.none)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: WeatherOverlay(
                            type: weather,
                            windSpeed: windSpeed,
                            highlight: weatherPalette.highlight,
                            accent: weatherPalette.accent,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;

  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    );
  }
}

class FieldLabel extends StatelessWidget {
  final String text;

  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final colors = BankTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colors.textMuted,
        ),
      ),
    );
  }
}

class AccountCard extends StatelessWidget {
  final Account account;
  final VoidCallback onTap;

  const AccountCard({
    super.key,
    required this.account,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = BankTheme.of(context);

    return ButtonMotion(
      enabled: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.divider),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              if (account.type == 'treasure_chest')
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(Icons.savings, color: Colors.amber.shade700, size: 24),
                ),
              if (account.isLoan)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.credit_card,
                      color: Colors.red.shade600,
                      size: 16,
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  account.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                account.type == 'treasure_chest'
                    ? '${account.balance} bars'
                    : _formatAmount(account.balance),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: account.type == 'treasure_chest'
                      ? Colors.amber.shade700
                      : colors.textMuted,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class BalanceSparkline extends StatelessWidget {
  final int currentBalance;
  final List<TransactionEntry> transactions;
  final bool placeholder;
  final int maxPoints;

  const BalanceSparkline({
    super.key,
    required this.currentBalance,
    required this.transactions,
    this.placeholder = false,
    this.maxPoints = 8,
  });

  List<int> _buildSeries() {
    final history = <int>[currentBalance];
    var running = currentBalance;
    for (final tx in transactions) {
      running += tx.isDebit ? tx.amount : -tx.amount;
      history.add(running);
    }
    final chronological = history.reversed.toList();
    return _sampleSeries(chronological);
  }

  List<int> _sampleSeries(List<int> series) {
    final limit = maxPoints < 2 ? 2 : maxPoints;
    if (series.length <= limit) return series;
    final step = (series.length - 1) / (limit - 1);
    return List<int>.generate(limit, (index) {
      final at = (index * step).round();
      final safeIndex = at.clamp(0, series.length - 1).toInt();
      return series[safeIndex];
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = BankTheme.of(context);
    final series = placeholder ? const <int>[] : _buildSeries();

    return CustomPaint(
      painter: _SparklinePainter(
        series: series,
        placeholder: placeholder,
        lineColor: colors.text,
        fillColor: colors.actionFill,
        gridColor: colors.divider,
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<int> series;
  final bool placeholder;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;

  const _SparklinePainter({
    required this.series,
    required this.placeholder,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const padding = 6.0;
    final width = size.width - padding * 2;
    final height = size.height - padding * 2;
    if (width <= 0 || height <= 0) return;

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (placeholder || series.length < 2) {
      linePaint.color = gridColor;
      final y = padding + height * 0.5;
      canvas.drawLine(Offset(padding, y), Offset(padding + width, y), linePaint);
      return;
    }

    final minValue = series.reduce((a, b) => a < b ? a : b).toDouble();
    final maxValue = series.reduce((a, b) => a > b ? a : b).toDouble();
    final range = (maxValue - minValue).abs() < 1 ? 1 : maxValue - minValue;

    final path = Path();
    final points = <Offset>[];
    for (var i = 0; i < series.length; i++) {
      final dx = padding + (width * i / (series.length - 1));
      final normalized = (series[i] - minValue) / range;
      final dy = padding + height - (normalized * height);
      points.add(Offset(dx, dy));
      if (i == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(padding + width, padding + height)
      ..lineTo(padding, padding + height)
      ..close();

    final fillPaint = Paint()
      ..color = fillColor.withAlpha(120)
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    _drawLabels(
      canvas,
      series,
      points,
      padding,
      width,
      height,
    );
  }

  void _drawLabels(
    Canvas canvas,
    List<int> series,
    List<Offset> points,
    double padding,
    double width,
    double height,
  ) {
    if (series.isEmpty) return;
    final labelIndexes = _selectLabelIndexes(series);
    if (labelIndexes.isEmpty) return;

    final labelStyle = TextStyle(
      color: lineColor,
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );
    final labelRects = <Rect>[];
    final dotPaint = Paint()..color = lineColor;
    final bgPaint = Paint()..color = fillColor.withAlpha(220);

    for (final index in labelIndexes) {
      final point = points[index];
      final value = series[index];
      final text = _formatSparkValue(value);
      final painter = TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      const gap = 6.0;
      const paddingX = 6.0;
      const paddingY = 3.0;
      final labelWidth = painter.width + paddingX * 2;
      final labelHeight = painter.height + paddingY * 2;

      var dx = point.dx - labelWidth / 2;
      dx = dx.clamp(padding, padding + width - labelWidth).toDouble();

      var dy = point.dy - labelHeight - gap;
      if (dy < padding) {
        dy = point.dy + gap;
      }
      if (dy + labelHeight > padding + height) {
        dy = point.dy - labelHeight - gap;
      }
      dy = dy.clamp(padding, padding + height - labelHeight).toDouble();

      final rect = Rect.fromLTWH(dx, dy, labelWidth, labelHeight);
      if (labelRects.any((other) => other.overlaps(rect))) {
        continue;
      }
      labelRects.add(rect);

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        bgPaint,
      );
      painter.paint(canvas, Offset(dx + paddingX, dy + paddingY));
      canvas.drawCircle(point, 2.5, dotPaint);
    }
  }

  List<int> _selectLabelIndexes(List<int> series) {
    if (series.length <= 3) {
      return List<int>.generate(series.length, (index) => index);
    }

    var minIndex = 0;
    var maxIndex = 0;
    for (var i = 1; i < series.length; i++) {
      if (series[i] < series[minIndex]) minIndex = i;
      if (series[i] > series[maxIndex]) maxIndex = i;
    }

    final ordered = <int>[];
    void addIndex(int index) {
      if (!ordered.contains(index)) {
        ordered.add(index);
      }
    }

    addIndex(series.length - 1);
    addIndex(maxIndex);
    addIndex(minIndex);
    if (series.length <= 5) {
      addIndex(0);
    }
    return ordered;
  }

  String _formatSparkValue(int value) {
    final absValue = value.abs();
    if (absValue >= 1000000) {
      return '\$${(value / 1000000).toStringAsFixed(1)}m';
    }
    if (absValue >= 1000) {
      return '\$${(value / 1000).toStringAsFixed(1)}k';
    }
    return '\$$value';
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return placeholder != oldDelegate.placeholder ||
        lineColor != oldDelegate.lineColor ||
        fillColor != oldDelegate.fillColor ||
        gridColor != oldDelegate.gridColor ||
        !listEquals(series, oldDelegate.series);
  }
}

class TransactionRow extends StatelessWidget {
  final TransactionEntry entry;

  const TransactionRow({
    super.key,
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = BankTheme.of(context);
    final sign = entry.isDebit ? '-' : '+';

    return ButtonMotion(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.divider),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                entry.description,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$sign${_formatAmount(entry.amount)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool fullWidth;
  final bool primary;
  final IconData? icon;

  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.fullWidth = false,
    this.primary = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = BankTheme.of(context);
    final borderColor = primary ? colors.text : colors.divider;
    final labelText = Text(
      label,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
    );
    final content = icon == null
        ? labelText
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: colors.text),
              const SizedBox(width: 8),
              labelText,
            ],
          );
    final button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        side: BorderSide(color: borderColor, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        backgroundColor: primary ? colors.actionFill : colors.surface,
        foregroundColor: colors.text,
      ),
      child: content,
    );

    final wrapped =
        fullWidth ? SizedBox(width: double.infinity, child: button) : button;
    return ButtonMotion(
      enabled: onPressed != null,
      child: wrapped,
    );
  }
}
