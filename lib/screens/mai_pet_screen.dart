import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../widgets/mai_face_painter.dart';

class MaiPetScreen extends StatefulWidget {
  const MaiPetScreen({super.key});

  @override
  State<MaiPetScreen> createState() => _MaiPetScreenState();
}

class _MaiPetScreenState extends State<MaiPetScreen>
    with TickerProviderStateMixin {
  MaiFaceState _faceState = MaiFaceState.normal;
  double _mood = 0.6;
  DateTime _lastInteraction = DateTime.now();

  Timer? _idleTimer;
  Timer? _tempStateTimer;

  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  static const double _faceSize = 260;
  final _random = math.Random();

  @override
  void initState() {
    super.initState();

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.07).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );

    _startIdleTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _tempStateTimer?.cancel();
    _bounceController.dispose();
    super.dispose();
  }

  // --- Estado según mood ---

  MaiFaceState _moodState() {
    if (_mood < 0.3) return MaiFaceState.sad;
    if (_mood > 0.7) return MaiFaceState.happy;
    return MaiFaceState.normal;
  }

  bool get _isInTempState =>
      _faceState == MaiFaceState.winkLeft ||
      _faceState == MaiFaceState.winkRight ||
      _faceState == MaiFaceState.angry;

  // --- Animaciones ---

  void _bounce() {
    _bounceController.stop();
    _bounceController.reset();
    _bounceController.forward().then((_) {
      if (mounted) _bounceController.reverse();
    });
  }

  void _setTempState(MaiFaceState state, {int durationMs = 600}) {
    _tempStateTimer?.cancel();
    setState(() => _faceState = state);
    _tempStateTimer = Timer(Duration(milliseconds: durationMs), () {
      if (mounted) setState(() => _faceState = _moodState());
    });
  }

  void _triggerWink({required bool isLeft, int durationMs = 600}) {
    _setTempState(
      isLeft ? MaiFaceState.winkLeft : MaiFaceState.winkRight,
      durationMs: durationMs,
    );
    _bounce();
  }

  void _triggerAngry() {
    _setTempState(MaiFaceState.angry, durationMs: 900);
    _bounce();
  }

  // --- Idle ---

  void _startIdleTimer() {
    _idleTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final secondsIdle = DateTime.now().difference(_lastInteraction).inSeconds;
      if (secondsIdle < 4 || _isInTempState) return;
      if (_random.nextDouble() < 0.08) _doIdleAnimation();
    });
  }

  void _doIdleAnimation() {
    final choice = _random.nextInt(10);
    if (choice < 4) {
      _triggerWink(isLeft: _random.nextBool());
    } else if (choice < 6) {
      _triggerWink(isLeft: _random.nextBool(), durationMs: 180); // parpadeo rápido
    } else if (choice < 9) {
      _bounce();
    } else {
      _triggerAngry();
    }
  }

  // --- Tap en la cara ---

  void _onTapDown(TapDownDetails details) {
    _lastInteraction = DateTime.now();
    if (_isInTempState) return;

    final tap = details.localPosition;

    const leftEye = Offset(
      _faceSize / 2 - _faceSize * 0.38 * 0.28,
      _faceSize / 2 - _faceSize * 0.38 * 0.08,
    );
    const rightEye = Offset(
      _faceSize / 2 + _faceSize * 0.38 * 0.28,
      _faceSize / 2 - _faceSize * 0.38 * 0.08,
    );
    const hitRadius = _faceSize * 0.38 * 0.28;

    if ((tap - leftEye).distance <= hitRadius) {
      _triggerWink(isLeft: true);
    } else if ((tap - rightEye).distance <= hitRadius) {
      _triggerWink(isLeft: false);
    } else {
      _bounce();
    }
  }

  // --- Slider de mood ---

  void _onMoodChanged(double value) {
    _lastInteraction = DateTime.now();
    setState(() {
      _mood = value;
      if (!_isInTempState) _faceState = _moodState();
    });
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('mai~'),
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTapDown: _onTapDown,
              child: AnimatedBuilder(
                animation: _bounceAnimation,
                builder: (context, _) => Transform.scale(
                  scale: _bounceAnimation.value,
                  child: SizedBox(
                    width: _faceSize,
                    height: _faceSize,
                    child: CustomPaint(
                      painter: MaiFacePainter(
                        state: _faceState,
                        faceColor: theme.colorScheme.primaryContainer,
                        accentColor: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
            _MoodBar(mood: _mood, onChanged: _onMoodChanged),
          ],
        ),
      ),
    );
  }
}

class _MoodBar extends StatelessWidget {
  final double mood;
  final ValueChanged<double> onChanged;

  const _MoodBar({required this.mood, required this.onChanged});

  Color _moodColor(double mood) {
    if (mood < 0.3) return Colors.blue[300]!;
    if (mood > 0.7) return Colors.pink[300]!;
    return Colors.purple[300]!;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('triste', style: Theme.of(context).textTheme.bodySmall),
              Text('feliz', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _moodColor(mood),
              thumbColor: _moodColor(mood),
              inactiveTrackColor: _moodColor(mood).withValues(alpha: 0.25),
            ),
            child: Slider(value: mood, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}
