import 'package:cloud_firestore/cloud_firestore.dart';

/// Who wrote a chat message.
enum ChatRole { customer, rider }

/// One message in `orders/{orderId}/messages`.
class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final ChatRole senderRole;
  final String text;

  /// Server time once saved; until then the phone's own clock.
  final DateTime sentAt;

  /// Still on its way to the server (shown with a clock icon).
  final bool isPending;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.text,
    required this.sentAt,
    this.isPending = false,
  });

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final sent = (data['sentAt'] as Timestamp?) ?? (data['clientSentAt'] as Timestamp?);
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderRole: data['senderRole'] == ChatRole.rider.name ? ChatRole.rider : ChatRole.customer,
      text: data['text'] ?? '',
      sentAt: sent?.toDate() ?? DateTime.now(),
      isPending: doc.metadata.hasPendingWrites,
    );
  }
}

/// Thrown when a message can't be sent; [message] is shown to the user.
class ChatException implements Exception {
  final String message;
  ChatException(this.message);
  @override
  String toString() => message;
}

/// Customer ↔ rider chat for one order, stored under the order so it is
/// cleaned up and secured together with it.
class ChatService {
  static const maxLength = 500;

  /// Only the latest messages are loaded; an order chat is short.
  static const historyLimit = 200;

  static CollectionReference<Map<String, dynamic>> _messages(String orderId) =>
      FirebaseFirestore.instance.collection('orders').doc(orderId).collection('messages');

  /// Oldest → newest, live. One orderBy on a subcollection needs no
  /// composite index.
  static Stream<List<ChatMessage>> messages(String orderId) => _messages(orderId)
      .orderBy('sentAt')
      .limitToLast(historyLimit)
      .snapshots()
      .map((snap) => snap.docs.map(ChatMessage.fromDoc).toList());

  static Future<void> send({
    required String orderId,
    required String senderId,
    required String senderName,
    required ChatRole senderRole,
    required String text,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw ChatException('Type a message first.');
    if (trimmed.length > maxLength) throw ChatException('Please keep messages under $maxLength characters.');
    return _messages(orderId).add({
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole.name,
      'text': trimmed,
      'sentAt': FieldValue.serverTimestamp(),
      'clientSentAt': Timestamp.now(),
    });
  }
}
