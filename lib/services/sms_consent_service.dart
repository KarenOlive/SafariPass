// lib/services/sms_consent_service.dart

import 'dart:async';
import 'package:sms_autofill/sms_autofill.dart';

class SmsConsentService with CodeAutoFill {
  Completer<String?>? _completer;
  String? _filter;

  Future<String?> requestSms({String? filter}) async {
    _filter = filter;
    _completer = Completer<String?>();

    await SmsAutoFill().listenForCode();

    return _completer!.future;
  }

  @override
  void codeUpdated() {
    final smsCode = code;

    if (smsCode == null) {
      _complete(null);
      return;
    }

    if (_filter != null && !smsCode.contains(_filter!)) {
      _complete(null);
      return;
    }

    _complete(smsCode);
  }

  void _complete(String? value) {
    if (!(_completer?.isCompleted ?? true)) {
      _completer?.complete(value);
    }
    cancel();
  }
}