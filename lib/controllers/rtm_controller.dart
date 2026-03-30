import 'dart:convert';
import 'dart:developer';

import 'package:agora_rtm/agora_rtm.dart';
import 'package:agora_uikit/controllers/session_controller.dart';
import 'package:agora_uikit/models/agora_rtm_channel_event_handler.dart';
import 'package:agora_uikit/models/agora_rtm_mute_request.dart';
import 'package:agora_uikit/models/rtm_message.dart';
import 'package:agora_uikit/src/enums.dart';

/// Function to join the RTM channel and send the user data to everyone inside that channel.
Future<void> rtmMethods(
    {required AgoraRtmChannelEventHandler agoraRtmChannelEventHandler,
    required SessionController sessionController}) async {
  final _ = agoraRtmChannelEventHandler;
  await _loginToRtm(sessionController);
  await _joinRtmChannel(sessionController);
  await sendUserData(
    toChannel: true,
    username: sessionController.value.connectionData!.username!,
    sessionController: sessionController,
  );
}

Future<void> _loginToRtm(SessionController sessionController) async {
  if (!sessionController.value.isLoggedIn) {
    try {
      final (status, _) = await sessionController.value.agoraRtmClient!.login(
        sessionController.value.connectionData!.tempRtmToken ??
        sessionController.value.generatedRtmToken ??
        '',
      );
      if (status.error) {
        throw Exception(status.reason);
      }

      sessionController.value =
          sessionController.value.copyWith(isLoggedIn: true);
      log(
        'Username : ${sessionController.value.connectionData!.username} and rtmId : ${sessionController.value.generatedRtmId} logged in',
        level: Level.info.value,
      );
    } catch (e) {
      log(
        'Error occurred while trying to login. ${e.toString()}',
        level: Level.error.value,
      );
    }
  }
}

Future<void> _joinRtmChannel(SessionController sessionController) async {
  if (!sessionController.value.isInChannel) {
    try {
      final channelName = sessionController.value.connectionData?.rtmChannelName ??
          sessionController.value.connectionData!.channelName;
      final (status, _) = await sessionController.value.agoraRtmClient!
          .subscribe(channelName, withMessage: true, withPresence: true);
      if (status.error) {
        throw Exception(status.reason);
      }

      sessionController.value = sessionController.value.copyWith(
        agoraRtmChannel: null,
      );
      sessionController.value =
          sessionController.value.copyWith(isInChannel: true);
    } catch (e) {
      log('RTM Join channel error : ${e.toString()}', level: Level.error.value);
    }
  }
}

Future<void> sendUserData({
  required bool toChannel,
  required String username,
  String? peerRtmId,
  required SessionController sessionController,
}) async {
  int ts = DateTime.now().millisecondsSinceEpoch;

  var userData = UserData(
    rtmId: sessionController.value.generatedRtmId!,
    rtcId: sessionController.value.localUid,
    username: username,
    role: sessionController.value.clientRoleType.index,
  );

  var json = jsonEncode(userData);

  Message message = Message(text: json, ts: ts, offline: false);

  if (sessionController.value.agoraRtmClient != null && toChannel) {
    final channelName = sessionController.value.connectionData?.rtmChannelName ??
        sessionController.value.connectionData!.channelName;
    await sessionController.value.agoraRtmClient?.publish(
      channelName,
      message.text,
    );
    log('User data sent to channel', level: Level.info.value);
  } else if (sessionController.value.agoraRtmClient != null &&
      !toChannel &&
      peerRtmId != null) {
    await sessionController.value.agoraRtmClient?.publish(
      peerRtmId,
      message.text,
      channelType: RtmChannelType.user,
    );
    log('User data sent to peer', level: Level.info.value);
  } else {
    log("No user in the channel", level: Level.warning.value);
  }
}
