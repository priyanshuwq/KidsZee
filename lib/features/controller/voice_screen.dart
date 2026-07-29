import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/doodle_background.dart';
import '../../core/network/smart_car_commands.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/orientation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENGLISH word map — checked per-word so "turn left now" → finds "LEFT".
// Includes common ASR mis-hearings for short/ambiguous words.
//
// Multi-word commands (rotate clockwise / anticlockwise) are handled by
// _matchWords which first checks for two-word phrases before single words.
// ─────────────────────────────────────────────────────────────────────────────

/// Two-word phrases checked first (order matters).
const _enPhraseMap = <String, String>{
  'ROTATE CLOCKWISE': 'RotateCW',
  'ROTATE RIGHT': 'RotateCW',
  'SPIN CLOCKWISE': 'RotateCW',
  'SPIN RIGHT': 'RotateCW',
  'ROTATE ANTICLOCKWISE': 'RotateCCW',
  'ROTATE COUNTERCLOCKWISE': 'RotateCCW',
  'ROTATE LEFT': 'RotateCCW',
  'SPIN ANTICLOCKWISE': 'RotateCCW',
  'SPIN COUNTERCLOCKWISE': 'RotateCCW',
  'SPIN LEFT': 'RotateCCW',
};

/// Single-word fallback map.
const _enWordMap = <String, String>{
  'FORWARD': 'Forward', 'FORWARDS': 'Forward',
  'BACKWARD': 'Backward', 'BACKWARDS': 'Backward', 'BACK': 'Backward',
  'RIGHT': 'Right', 'WRITE': 'Right',
  'LEFT': 'Left', 'LIFT': 'Left', 'LOFT': 'Left', 'LAUGHED': 'Left',
  'LAPPED': 'Left', 'LEPT': 'Left', 'LEAPT': 'Left', 'LEFTS': 'Left',
};
const _enChips = ['Forward', 'Backward', 'Right', 'Left', 'Rotate CW', 'Rotate CCW'];

class VoiceScreen extends ConsumerStatefulWidget {
  const VoiceScreen({super.key});
  @override
  ConsumerState<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends ConsumerState<VoiceScreen> with SingleTickerProviderStateMixin {
  final _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechReady = false;
  String _detected = '';
  String _subtitle = 'Tap the mic to start';
  final List<String> _log = [];
  late AnimationController _rotCtrl;
  Timer? _autoStopTimer;

  @override
  void initState() {
    super.initState();
    _rotCtrl = AnimationController(vsync: this, duration: 3000.ms)..repeat();
    lockLandscape();
    _speech.initialize().then((ok) { if (mounted) setState(() => _speechReady = ok); });
  }

  @override
  void dispose() {
    _autoStopTimer?.cancel();
    _rotCtrl.dispose();
    _speech.stop();
    super.dispose();
  }

  void _sendVoiceCommand(String matched) {
    // Cancel any pending auto-stop from a previous command.
    _autoStopTimer?.cancel();

    switch (matched) {
      case 'Forward':
        SmartCarCommands.send(CarDirection.forward);
        _autoStopTimer = Timer(const Duration(seconds: 2), SmartCarCommands.stop);
        break;
      case 'Backward':
        SmartCarCommands.send(CarDirection.backward);
        _autoStopTimer = Timer(const Duration(seconds: 2), SmartCarCommands.stop);
        break;
      case 'Left':
        SmartCarCommands.send(CarDirection.left);
        _autoStopTimer = Timer(const Duration(milliseconds: 250), SmartCarCommands.stop);
        break;
      case 'Right':
        SmartCarCommands.send(CarDirection.right);
        _autoStopTimer = Timer(const Duration(milliseconds: 250), SmartCarCommands.stop);
        break;
      case 'RotateCW':
        SmartCarCommands.send(CarDirection.right);
        _autoStopTimer = Timer(const Duration(seconds: 2), SmartCarCommands.stop);
        break;
      case 'RotateCCW':
        SmartCarCommands.send(CarDirection.left);
        _autoStopTimer = Timer(const Duration(seconds: 2), SmartCarCommands.stop);
        break;
    }
  }

  /// Match recognised text against phrase and word maps.
  /// 1) Check two-word phrases first (e.g. "rotate clockwise").
  /// 2) Per-word exact match (handles "turn left now" → "LEFT").
  /// 3) Substring fallback (≥3 chars) for merged outputs.
  static String? _matchWords(String text, Map<String, String> wordMap) {
    final upper = text.toUpperCase();

    // Phrase matching first — longest match wins.
    for (final entry in _enPhraseMap.entries) {
      if (upper.contains(entry.key)) return entry.value;
    }

    // Single-word matching.
    final words = upper.split(RegExp(r'\s+'));
    for (final word in words) {
      if (wordMap.containsKey(word)) return wordMap[word];
    }
    for (final entry in wordMap.entries) {
      if (entry.key.length >= 3 && upper.contains(entry.key)) return entry.value;
    }
    return null;
  }

  // ── Listening ─────────────────────────────────────────────────────────────

  Future<void> _toggle() async {
    if (_isListening) {
      await _speech.stop();
      setState(() { _isListening = false; _subtitle = 'Tap the mic to start'; });
      return;
    }

    if (!_speechReady) {
      final ok = await _speech.initialize();
      if (!ok) { setState(() => _subtitle = 'Speech not available'); return; }
      _speechReady = true;
    }

    setState(() { _isListening = true; _detected = ''; _subtitle = 'Listening…'; });
    ref.hapticFeedback(HapticStrength.medium);
    _startListening();
  }

  void _startListening() {
    if (!mounted || !_isListening) return;

    _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        sampleRate: 44100,
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        localeId: 'en-US',
      ),
      onResult: (result) {
        if (!_isListening) return;

        final raw = result.recognizedWords;
        final matched = _matchWords(raw, _enWordMap);

        if (matched != null) {
          final cmd = matched;
          _speech.stop();
          ref.hapticFeedback(HapticStrength.heavy);

          // Display label for rotate commands.
          final displayLabel = switch (cmd) {
            'RotateCW' => 'ROTATE CW',
            'RotateCCW' => 'ROTATE CCW',
            _ => cmd.toUpperCase(),
          };

          setState(() {
            _isListening = false;
            _detected = displayLabel;
            _subtitle = 'Tap the mic again';
            _log.insert(0, displayLabel);
            if (_log.length > 6) _log.removeLast();
          });
          _sendVoiceCommand(cmd);
        } else {
          setState(() => _detected = raw.length > 30 ? '${raw.substring(0, 30)}…' : raw);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chips = _enChips;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: DoodleBackground(
        child: SafeArea(
          child: Column(children: [
            _TopBar(onBack: () => Navigator.of(context).maybePop()),
            Expanded(child: _buildLandscape(chips)),
          ]),
        ),
      ),
    );
  }

  Widget _buildLandscape(List<String> chips) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
      child: Row(children: [
        Expanded(flex: 4, child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
          _buildDetectionBox(),
          const SizedBox(height: 16),
          Flexible(child: _buildMicArea()),
        ])),
        const SizedBox(width: 32),
        Expanded(flex: 6, child: SingleChildScrollView(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: chips.map((cmd) => _Chip(label: cmd)).toList()),
          const SizedBox(height: 24),
          if (_log.isNotEmpty) _buildLogBox(),
        ]))),
      ]),
    );
  }

  Widget _buildDetectionBox() => Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 20),
    decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border, width: 1.5)),
    child: Center(child: Text(_detected.isEmpty ? '—' : _detected, style: AppTypography.monoLarge())),
  ).animate().fadeIn();

  Widget _buildMicArea() => Column(mainAxisSize: MainAxisSize.min, children: [
    Stack(alignment: Alignment.center, children: [
      if (_isListening) AnimatedBuilder(animation: _rotCtrl,
        builder: (_, __) => Transform.rotate(angle: _rotCtrl.value * 2 * math.pi,
          child: SizedBox(width: 120, height: 120, child: CustomPaint(painter: _DottedCircle())))),
      GestureDetector(onTap: _toggle,
        child: AnimatedContainer(duration: 200.ms, width: 88, height: 88,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: _isListening ? AppColors.orange : AppColors.cardWhite,
            border: Border.all(color: _isListening ? AppColors.orange : AppColors.border, width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: _isListening ? 0.12 : 0.06), offset: const Offset(0, 3), blurRadius: _isListening ? 12 : 8)]),
          child: Icon(Icons.mic, size: 40, color: _isListening ? Colors.white : AppColors.navy))),
    ]),
    const SizedBox(height: 10),
    Text(_subtitle, style: AppTypography.body().copyWith(color: _isListening ? AppColors.orange : AppColors.navy)),
  ]);

  Widget _buildLogBox() => Container(width: double.infinity, padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border, width: 1.5)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Recent Commands', style: AppTypography.label()),
      const SizedBox(height: 8),
      ..._log.map((l) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('• $l', style: AppTypography.statusText()))),
    ])).animate().fadeIn();
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Row(children: [
      GestureDetector(onTap: onBack, child: Container(width: 40, height: 40,
        decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
        child: const Icon(Icons.arrow_back_ios_new, color: AppColors.navy, size: 18))),
      const SizedBox(width: 16),
      Text('Voice Control', style: AppTypography.headline3().copyWith(fontSize: 18)),
    ]));
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border, width: 1.5)),
    child: Text(label, style: AppTypography.chipText().copyWith(fontSize: 14)));
}

class _DottedCircle extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.orange..strokeWidth = 2.5..style = PaintingStyle.stroke;
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 2;
    for (int i = 0; i < 16; i++) {
      final angle = i * math.pi / 8;
      final start = Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
      final end = Offset(center.dx + r * math.cos(angle + 0.2), center.dy + r * math.sin(angle + 0.2));
      canvas.drawLine(start, end, paint);
    }
  }
  @override bool shouldRepaint(_) => false;
}
