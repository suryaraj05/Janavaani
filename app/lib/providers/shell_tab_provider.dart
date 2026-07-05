import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Controls the bottom navigation index inside [PpShellScreen].
final shellTabProvider = StateProvider<int>((ref) => 0);
