import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_design_system.dart';
import '../../services/offline_queue.dart';
import '../../widgets/design_system/app_button.dart';
import '../../widgets/design_system/app_snackbar.dart';

// ignore: depend_on_referenced_packages
import 'dart:io' if (dart.library.html) '../../utils/io_stub.dart' show File, Directory;

class SubmitRequestScreen extends ConsumerStatefulWidget {
  const SubmitRequestScreen({super.key});

  @override
  ConsumerState<SubmitRequestScreen> createState() => _SubmitRequestScreenState();
}

class _SubmitRequestScreenState extends ConsumerState<SubmitRequestScreen>
    with SingleTickerProviderStateMixin {
  static const _localeKey = 'pp_display_locale';
  static const _maxSeconds = 60;

  final _recorder = AudioRecorder();
  final _tts = FlutterTts();
  final _textController = TextEditingController();

  String _locale = 'te';
  bool _isRecording = false;
  bool _isSubmitting = false;
  String? _audioPath;
  XFile? _photo;
  Position? _position;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _loadLocale();
    _captureGps();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _locale = prefs.getString(_localeKey) ?? 'te');
  }

  Future<void> _saveLocale(String locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale);
    setState(() => _locale = locale);
  }

  Future<void> _captureGps() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      _position = await Geolocator.getCurrentPosition();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      _recordTimer?.cancel();
      final path = await _recorder.stop();
      setState(() {
        _isRecording = false;
        _audioPath = path;
        _recordSeconds = 0;
      });
      return;
    }

    if (!await _recorder.hasPermission()) {
      if (mounted) AppSnackbar.error(context, 'Microphone permission required');
      return;
    }

    final dir = kIsWeb ? null : Directory.systemTemp;
    final path = kIsWeb
        ? 'pp_voice_${DateTime.now().millisecondsSinceEpoch}.m4a'
        : '${dir!.path}/pp_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (_recordSeconds + 1 >= _maxSeconds) {
        await _toggleRecording();
        return;
      }
      if (mounted) setState(() => _recordSeconds++);
    });
    setState(() {
      _isRecording = true;
      _audioPath = null;
      _recordSeconds = 0;
    });
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (image != null) setState(() => _photo = image);
  }

  Future<String?> _readAudioBase64() async {
    if (_audioPath == null) return null;
    if (kIsWeb) return null; // web recording handled as text-only for now
    try {
      final bytes = await File(_audioPath!).readAsBytes();
      return base64Encode(bytes);
    } catch (_) {
      return null;
    }
  }

  Future<void> _submit() async {
    if (_audioPath == null && _textController.text.trim().isEmpty) {
      AppSnackbar.error(context, 'Record a voice note or enter text');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final audioBase64 = await _readAudioBase64();

      List<String>? images;
      if (_photo != null) {
        final bytes = await _photo!.readAsBytes();
        images = [base64Encode(bytes)];
      }

      final draft = {
        'source': 'app',
        'citizen': {
          'citizen_hash': null,
          'auth_kind': 'firebase_uid',
          'display_locale': _locale,
        },
        'content': {
          'modality': _audioPath != null
              ? (_photo != null ? 'photo_text' : 'voice')
              : (_photo != null ? 'photo_text' : 'text'),
          'original_text': _textController.text.trim().isEmpty ? null : _textController.text.trim(),
          'original_language': _locale,
          'media': [],
        },
        'location': {
          if (_position != null)
            'point': {'lat': _position!.latitude, 'lng': _position!.longitude},
        },
        'channel_meta': {},
      };

      final sent = await OfflineQueue.instance.submitOrQueue(
        draft: draft,
        audioBase64: audioBase64,
        imagesBase64: images,
      );

      await _speakConfirmation(sent);
      if (mounted) {
        AppSnackbar.success(
          context,
          sent ? 'Request submitted — AI is processing' : 'Saved offline — will send when online',
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'Submit failed: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _speakConfirmation(bool sent) async {
    const ttsLocale = {'te': 'te-IN', 'hi': 'hi-IN', 'en': 'en-IN'};
    const sentMsg = {
      'te': 'మీ విన్నపం స్వీకరించబడింది. ధన్యవాదాలు.',
      'hi': 'आपका अनुरोध प्राप्त हो गया है। धन्यवाद।',
      'en': 'Your request has been received. Thank you.',
    };
    const queuedMsg = {
      'te': 'మీ విన్నపం సేవ్ చేయబడింది.',
      'hi': 'आपका अनुरोध सहेजा गया है।',
      'en': 'Your request is saved for later.',
    };
    try {
      await _tts.setLanguage(ttsLocale[_locale] ?? 'en-IN');
      await _tts.speak((sent ? sentMsg[_locale] : queuedMsg[_locale]) ?? '');
    } catch (_) {}
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _pulseController.dispose();
    _recorder.dispose();
    _tts.stop();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const localeLabels = {'te': 'తెలుగు', 'hi': 'हिंदी', 'en': 'English'};
    const localeHints = {
      'te': 'మీ ఊరికి ఏమి కావాలో చెప్పండి…',
      'hi': 'अपने क्षेत्र की जरूरत बताएं…',
      'en': 'Describe what your area needs…',
    };

    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundColor,
      appBar: AppBar(
        title: const Text('Share Your Priority'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Your language', style: AppDesignSystem.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: localeLabels.entries
                  .map((e) => ButtonSegment(value: e.key, label: Text(e.value)))
                  .toList(),
              selected: {_locale},
              onSelectionChanged: (s) => _saveLocale(s.first),
            ),
            const SizedBox(height: 28),
            Text(
              localeHints[_locale] ?? localeHints['en']!,
              style: AppDesignSystem.heading3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Center(
              child: GestureDetector(
                onTap: _toggleRecording,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scale = _isRecording ? 1.0 + _pulseController.value * 0.08 : 1.0;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: _isRecording
                                ? [Colors.red.shade600, Colors.red.shade400]
                                : [AppDesignSystem.primaryColor, AppDesignSystem.primaryLight],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_isRecording ? Colors.red : AppDesignSystem.primaryColor)
                                  .withValues(alpha: 0.35),
                              blurRadius: 24,
                              spreadRadius: _isRecording ? 4 : 0,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                          color: Colors.white,
                          size: 52,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isRecording
                  ? 'Recording $_recordSeconds / $_maxSeconds s'
                  : (_audioPath != null ? 'Voice recorded ✓' : 'Tap to record (max $_maxSeconds s)'),
              textAlign: TextAlign.center,
              style: AppDesignSystem.bodyMedium.copyWith(
                color: _isRecording ? Colors.red : AppDesignSystem.textSecondary,
                fontWeight: _isRecording ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                labelText: 'Or type your request',
                hintText: localeHints[_locale],
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _pickPhoto,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text(_photo != null ? 'Photo attached ✓' : 'Add photo (optional)'),
            ),
            if (_position != null) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on, size: 14, color: AppDesignSystem.secondaryColor),
                  const SizedBox(width: 4),
                  Text(
                    'GPS attached · ${_position!.latitude.toStringAsFixed(4)}, ${_position!.longitude.toStringAsFixed(4)}',
                    style: AppDesignSystem.bodySmall,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 28),
            AppButton(
              onPressed: _isSubmitting ? null : _submit,
              label: _isSubmitting ? 'Submitting…' : 'Submit Request',
              isLoading: _isSubmitting,
            ),
          ],
        ),
      ),
    );
  }
}
