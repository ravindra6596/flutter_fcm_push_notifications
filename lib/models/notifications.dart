class NotificationModel {
  String? notificationId;
  String? title;
  String? body;
  String? receivedAt;
  String? type;
  bool isReadNotification;

  NotificationModel({
    this.notificationId,
    this.title,
    this.body,
    this.receivedAt,
    this.type,
    this.isReadNotification = true,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      notificationId: map['notificationId'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      receivedAt: map['receivedAt'] ?? '',
      type: map['type'] ?? '',
      isReadNotification: map['isReadNotification'] == 1,
    );
  }
}
