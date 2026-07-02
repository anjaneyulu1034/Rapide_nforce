import 'package:flutter/material.dart';
import 'package:rapide_nforce/models/work_order_model.dart';

class WorkOrderStatusChip extends StatelessWidget {
  const WorkOrderStatusChip({
    super.key,
    required this.status,
    this.compact = false,
  });

  final WorkOrderStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: status.backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w600,
          color: status.textColor,
        ),
      ),
    );
  }
}

class WorkOrderPriorityChip extends StatelessWidget {
  const WorkOrderPriorityChip({super.key, required this.priority});

  final WorkOrderPriority priority;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: priority.backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        priority.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: priority.textColor,
        ),
      ),
    );
  }
}
