class AgoraRtmChannelEventHandler {
  /// Occurs when you receive error events.
  final void Function(dynamic error)? onError;

  /// Occurs when receiving a channel message.
  final void Function(String message, String fromUserId)? onMessageReceived;

  /// Occurs when a user joins the channel.
  final void Function(String userId)? onMemberJoined;

  /// Occurs when a channel member leaves the channel.
  final void Function(String userId)? onMemberLeft;

  /// Occurs when channel attribute updated.
  final void Function(dynamic attributes)? onAttributesUpdated;

  /// Occurs when channel member count updated.
  final Function(int count)? onMemberCountUpdated;

  const AgoraRtmChannelEventHandler({
    this.onError,
    this.onMessageReceived,
    this.onMemberJoined,
    this.onMemberLeft,
    this.onAttributesUpdated,
    this.onMemberCountUpdated,
  });
}
