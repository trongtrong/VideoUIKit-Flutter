import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:agora_rtm/agora_rtm.dart';
import 'package:agora_uikit/controllers/rtm_controller_helper.dart';
import 'package:agora_uikit/controllers/rtm_controller.dart';
import 'package:agora_uikit/controllers/rtm_token_handler.dart';
import 'package:agora_uikit/controllers/session_controller.dart';
import 'package:agora_uikit/models/agora_rtm_channel_event_handler.dart';
import 'package:agora_uikit/models/agora_rtm_client_event_handler.dart';
import 'package:agora_uikit/models/rtm_message.dart';
import 'package:agora_uikit/src/enums.dart';

Future<void> rtmClientEventHandler({
  required RtmClient agoraRtmClient,
  required AgoraRtmClientEventHandler agoraRtmClientEventHandler,
  required AgoraRtmChannelEventHandler agoraRtmChannelEventHandler,
  required SessionController sessionController,
}) async {
  const String tag = "AgoraVideoUIKit";

  agoraRtmClient.addListener(
    message: (event) {
      final payload = utf8.decode(event.message ?? Uint8List(0));
      final publisher = event.publisher ?? '';
      if (payload.isEmpty) return;

      if (event.channelType == RtmChannelType.user) {
        agoraRtmClientEventHandler.onMessageReceived?.call(payload, publisher);
      } else {
        agoraRtmChannelEventHandler.onMessageReceived
            ?.call(payload, publisher);
      }

      try {
        final body = json.decode(payload);
        final messageType = body['messageType'] as String?;
        if (messageType == null) return;

        messageReceived(
          messageType: messageType,
          message: Message(text: payload).toJson(),
          sessionController: sessionController,
        );
      } catch (_) {
        log('Ignoring non-JSON RTM message payload',
            level: Level.warning.value, name: tag);
      }
    },
    linkState: (event) {
      final state = event.currentState ?? RtmLinkState.idle;
      final reason = event.reasonCode ?? RtmLinkStateChangeReason.unknown;
      agoraRtmClientEventHandler.onConnectionStateChanged2?.call(state, reason);

      log(
        'Connection state changed : ${state.toString()}, reason : ${reason.toString()}',
        level: Level.info.value,
        name: tag,
      );
      if (state == RtmLinkState.failed) {
        agoraRtmClient.logout();
      }
    },
    presence: (event) {
      final joined = event.interval?.joinUserList?.users ?? const <String>[];
      for (final userId in joined) {
        agoraRtmChannelEventHandler.onMemberJoined?.call(userId);
        sendUserData(
          toChannel: false,
          username: sessionController.value.connectionData!.username!,
          peerRtmId: userId,
          sessionController: sessionController,
        );
      }

      final left = event.interval?.leaveUserList?.users ?? const <String>[];
      for (final userId in left) {
        agoraRtmChannelEventHandler.onMemberLeft?.call(userId);
        if (sessionController.value.userRtmMap?.containsKey(userId) ?? false) {
          removeFromUserRtmMap(
            rtmId: userId,
            sessionController: sessionController,
          );
        }

        if (sessionController.value.uidToUserIdMap?.containsValue(userId) ??
            false) {
          final matchedRtcIds = sessionController.value.uidToUserIdMap!.entries
              .where((entry) => entry.value == userId)
              .map((entry) => entry.key)
              .toList();
          for (final rtcId in matchedRtcIds) {
            removeFromUidToUserMap(
              rtcId: rtcId,
              sessionController: sessionController,
            );
          }
        }
      }

      final count = event.snapshot?.userStateList?.length ??
          ((sessionController.value.userRtmMap?.length ?? 0) + 1);
      agoraRtmChannelEventHandler.onMemberCountUpdated?.call(count);
    },
    token: (event) {
      if (event.eventType == RtmTokenEventType.willExpire) {
        agoraRtmClientEventHandler.onTokenPrivilegeWillExpire?.call();
        getRtmToken(
          tokenUrl: sessionController.value.connectionData!.tokenUrl,
          sessionController: sessionController,
        );
      } else if (event.eventType == RtmTokenEventType.readPermissionRevoked) {
        agoraRtmClientEventHandler.onTokenExpired?.call();
      }
    },
  );

  agoraRtmClientEventHandler.onPeersOnlineStatusChanged?.call(
    const <String, dynamic>{},
  );
}
