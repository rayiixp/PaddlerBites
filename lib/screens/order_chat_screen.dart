import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/errors.dart';
import '../core/formatters.dart';
import '../models/models.dart';
import '../providers/user_provider.dart';
import '../services/chat_service.dart';
import '../services/order_service.dart';
import '../services/user_service.dart';
import '../widgets/custom_dialogs.dart';

/// Customer ↔ rider chat for one order. Opened from the customer's tracking
/// screen and the rider's active delivery screen.
///
/// Firebase sync: messages live in `orders/{orderId}/messages` and stream in
/// real time to both phones; the order itself is streamed to know who is
/// talking to whom and whether the chat is still open.
class OrderChatScreen extends StatefulWidget {
  final String orderId;
  const OrderChatScreen({super.key, required this.orderId});

  static Future<void> open(BuildContext context, String orderId) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => OrderChatScreen(orderId: orderId)));

  @override
  State<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends State<OrderChatScreen> {
  late final Stream<OrderModel?> _order = OrderService.orderStream(widget.orderId);
  late final Stream<List<ChatMessage>> _messages = ChatService.messages(widget.orderId);

  @override
  Widget build(BuildContext context) {
    final myName = context.watch<UserProvider>().userData?['name'] as String?;
    return OrderChatView(
      orderUpdates: _order,
      messages: _messages,
      currentUserId: UserService.uid,
      onSend: (order, role, text) => ChatService.send(
        orderId: order.id,
        senderId: UserService.uid,
        senderName: myName ?? (role == ChatRole.rider ? order.deliveryPersonName ?? 'Rider' : order.customerName),
        senderRole: role,
        text: text,
      ),
    );
  }
}

/// The chat UI, fed by plain streams so it can run without Firebase.
class OrderChatView extends StatelessWidget {
  final Stream<OrderModel?> orderUpdates;
  final Stream<List<ChatMessage>> messages;
  final String currentUserId;
  final Future<void> Function(OrderModel order, ChatRole role, String text) onSend;

  const OrderChatView({
    super.key,
    required this.orderUpdates,
    required this.messages,
    required this.currentUserId,
    required this.onSend,
  });

  /// Which side of the order the viewer is on, or null if neither.
  static ChatRole? roleOf(OrderModel order, String uid) {
    if (order.deliveryPersonId == uid) return ChatRole.rider;
    if (order.customerId == uid) return ChatRole.customer;
    return null;
  }

  /// Messages can be sent while the order is in progress and has a rider.
  static bool isOpen(OrderModel order) => order.isActive && order.deliveryPersonId != null;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<OrderModel?>(
      stream: orderUpdates,
      builder: (context, snapshot) {
        final order = snapshot.data;
        final role = order == null ? null : roleOf(order, currentUserId);
        final otherName = switch (role) {
          ChatRole.customer => order!.deliveryPersonName ?? 'Your rider',
          ChatRole.rider => order!.customerName,
          null => 'Chat',
        };

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0.5,
            titleSpacing: 0,
            title: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.primaryColor,
                  child: Icon(role == ChatRole.customer ? Icons.kayaking : Icons.person, color: Colors.black, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(otherName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      if (order != null)
                        Text(
                          '${role == ChatRole.customer ? 'Your rider' : 'Customer'} · Order ${order.shortId} · ${order.status}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: switch ((snapshot.connectionState, order, role)) {
            (ConnectionState.waiting, null, _) => const Center(child: CircularProgressIndicator()),
            (_, null, _) => const _Notice(text: 'This order no longer exists.'),
            (_, _, null) => const _Notice(text: 'Only the customer and the rider of this order can chat.'),
            _ => Column(
                children: [
                  Expanded(child: _MessageList(messages: messages, currentUserId: currentUserId, otherName: otherName)),
                  if (isOpen(order!))
                    _Composer(onSend: (text) => onSend(order, role!, text))
                  else
                    _ClosedBar(order: order),
                ],
              ),
          },
        );
      },
    );
  }
}

class _MessageList extends StatelessWidget {
  final Stream<List<ChatMessage>> messages;
  final String currentUserId;
  final String otherName;
  const _MessageList({required this.messages, required this.currentUserId, required this.otherName});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatMessage>>(
      stream: messages,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _Notice(text: 'Could not load messages. ${friendlyError(snapshot.error!)}');
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final list = snapshot.data!;
        if (list.isEmpty) {
          return _Notice(
            icon: Icons.chat_bubble_outline,
            text: 'No messages yet.\nSay hi to $otherName — ask about the drop-off, directions or your order.',
          );
        }
        // Reversed list: the newest message sits at the bottom and new ones
        // appear without manual scrolling.
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final message = list[list.length - 1 - i];
            final older = i + 1 < list.length ? list[list.length - 2 - i] : null;
            final showDay = older == null || !isSameDay(older.sentAt, message.sentAt);
            return Column(
              children: [
                if (showDay) _DayLabel(time: message.sentAt),
                _Bubble(message: message, isMine: message.senderId == currentUserId),
              ],
            );
          },
        );
      },
    );
  }
}

class _DayLabel extends StatelessWidget {
  final DateTime time;
  const _DayLabel({required this.time});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final text = isSameDay(time, now) ? 'Today' : formatDateTime(time).split(',').first;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(text, style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  const _Bubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    const radius = Radius.circular(18);
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(14, 9, 14, 7),
          decoration: BoxDecoration(
            color: isMine ? AppTheme.primaryColor : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: radius,
              topRight: radius,
              bottomLeft: isMine ? radius : const Radius.circular(4),
              bottomRight: isMine ? const Radius.circular(4) : radius,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                widthFactor: 1,
                child: Text(message.text, style: const TextStyle(fontSize: 15, height: 1.3)),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(formatTime(message.sentAt), style: TextStyle(fontSize: 10.5, color: Colors.black.withValues(alpha: 0.5))),
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.isPending ? Icons.schedule : Icons.done,
                      size: 12,
                      color: Colors.black.withValues(alpha: 0.5),
                      semanticLabel: message.isPending ? 'Sending' : 'Sent',
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text field and send button. The field clears immediately so the chat feels
/// instant; the message shows with a clock until the server has it, and the
/// text comes back if sending fails.
class _Composer extends StatefulWidget {
  final Future<void> Function(String text) onSend;
  const _Composer({required this.onSend});

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    unawaited(Future.sync(() => widget.onSend(text)).catchError((Object e) {
      if (!mounted) return;
      if (_controller.text.isEmpty) _controller.text = text; // let them retry
      showAppSnackBar(context, 'Message not sent. ${friendlyError(e)}', isError: true);
    }));
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _controller.text.trim().isNotEmpty;
    return Material(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: ChatService.maxLength,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Type a message…',
                    counterText: '',
                    isDense: true,
                    filled: true,
                    fillColor: AppTheme.backgroundColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Send',
                onPressed: canSend ? _send : null,
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.grey.shade200,
                  minimumSize: const Size(46, 46),
                ),
                icon: const Icon(Icons.send_rounded, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClosedBar extends StatelessWidget {
  final OrderModel order;
  const _ClosedBar({required this.order});

  @override
  Widget build(BuildContext context) {
    final text = switch (order.status) {
      OrderStatus.delivered => 'This order was delivered, so the chat is closed.',
      OrderStatus.cancelled => 'This order was cancelled, so the chat is closed.',
      _ => 'Chat opens once a rider accepts this order.',
    };
    return Material(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;
  final IconData? icon;
  const _Notice({required this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
            ],
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
