class NotificationModel {
  String? notificationId;
  String? title;
  String? body;
  String? receivedAt;
  String? type;

  NotificationModel({
    this.notificationId,
    this.title,
    this.body,
    this.receivedAt,
    this.type,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      notificationId: map['notificationId'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      receivedAt: map['receivedAt'] ?? '',
      type: map['type'] ?? '',
    );
  }
}
