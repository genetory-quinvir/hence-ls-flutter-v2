import 'package:flutter/cupertino.dart';

import '../../common/auth/auth_store.dart';
import '../../profile/models/profile_display_user.dart';
import '../../profile_info/profile_info_view.dart';

Future<void> showProfileModal(
  BuildContext context, {
  required ProfileDisplayUser user,
  bool allowCurrentUser = false,
}) {
  final currentUserId = AuthStore.instance.currentUser.value?.id;
  if (!allowCurrentUser &&
      currentUserId != null &&
      currentUserId.isNotEmpty &&
      currentUserId == user.id) {
    return Future.value();
  }
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (_) => SizedBox.expand(
      child: ProfileInfoView(user: user),
    ),
  );
}
