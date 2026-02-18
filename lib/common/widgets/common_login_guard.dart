import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../auth/auth_store.dart';
import 'common_alert_view.dart';
import '../../sign/sign_view.dart';

class CommonLoginGuard {
  CommonLoginGuard._();

  static Future<bool> ensureSignedIn(
    BuildContext context, {
    required String title,
    required String subTitle,
  }) async {
    if (AuthStore.instance.isSignedIn.value) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Material(
          type: MaterialType.transparency,
          child: CommonAlertView(
            title: title,
            subTitle: subTitle,
            primaryButtonTitle: '로그인하기',
            secondaryButtonTitle: '취소',
            onPrimaryTap: () => Navigator.of(dialogContext).pop(true),
            onSecondaryTap: () => Navigator.of(dialogContext).pop(false),
          ),
        );
      },
    );
    if (confirmed == true) {
      if (!context.mounted) return false;
      showCupertinoModalPopup(
        context: context,
        builder: (_) => const SizedBox.expand(
          child: SignView(),
        ),
      );
    }
    return false;
  }
}
