import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// Opens the device Messages app with a number and body already filled in.
/// The user reviews the draft and presses Send themselves.
class NativeSms {
  const NativeSms._();

  /// Reads `phone`, then `phoneNumber`, from the actor document.
  static Future<String> phoneForActor(String actorId) async {
    final id = actorId.trim();
    if (id.isEmpty) {
      throw Exception('This actor does not have a phone number on file.');
    }

    final doc =
        await FirebaseFirestore.instance.collection('actors').doc(id).get();
    if (!doc.exists) {
      throw Exception('Actor profile not found.');
    }

    final data = doc.data() ?? const <String, dynamic>{};
    final raw = _firstPhone(data);
    if (raw.isEmpty) {
      throw Exception('This actor does not have a phone number on file.');
    }

    final normalized = normalizeIndianMobile(raw);
    if (normalized == null) {
      throw Exception('This actor does not have a valid mobile number on file.');
    }
    return normalized;
  }

  /// Accepts 10-digit, 0-prefixed, or +91 Indian mobile numbers.
  static String? normalizeIndianMobile(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final String local;
    if (digits.length == 12 && digits.startsWith('91')) {
      local = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      local = digits.substring(1);
    } else if (digits.length == 10) {
      local = digits;
    } else {
      return null;
    }

    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(local)) return null;
    return '+91$local';
  }

  /// Android uses `sms:number?body=`. iOS uses `sms:number&body=`.
  static Future<void> openComposer({
    required String phone,
    required String message,
  }) async {
    if (kIsWeb) {
      throw Exception('Open the AATT app on your phone to send an SMS.');
    }

    final body = Uri.encodeComponent(message);
    // iOS only fills the message when the body is joined with `&`.
    // Pass the string through unchanged so `&` is not re-encoded.
    final separator =
        defaultTargetPlatform == TargetPlatform.iOS ? '&' : '?';
    final smsUrl = 'sms:$phone${separator}body=$body';

    final opened = await launchUrlString(
      smsUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      throw Exception('Could not open the Messages app on this device.');
    }
  }

  static String _firstPhone(Map<String, dynamic> data) {
    for (final key in const ['phone', 'phoneNumber']) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }
}
