import 'package:flutter/material.dart';
import 'package:frontend/app/theme.dart';

class FromToInput extends StatelessWidget {
  final String origin;
  final String destination;
  final ValueChanged<String> onOriginChanged;
  final ValueChanged<String> onDestinationChanged;
  final VoidCallback onSwap;
  final VoidCallback onSubmit;

  const FromToInput({
    super.key,
    required this.origin,
    required this.destination,
    required this.onOriginChanged,
    required this.onDestinationChanged,
    required this.onSwap,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Route dots indicator
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              Container(width: 2, height: 28, color: AppColors.border),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Text fields
          Expanded(
            child: Column(
              children: [
                _InputField(
                  value: origin,
                  hint: 'Origin',
                  onChanged: onOriginChanged,
                  onSubmitted: (_) => onSubmit(),
                ),
                const Divider(height: 12, color: AppColors.borderLight),
                _InputField(
                  value: destination,
                  hint: 'Where to?',
                  onChanged: onDestinationChanged,
                  onSubmitted: (_) => onSubmit(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Swap button
          GestureDetector(
            onTap: onSwap,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.swap_vert,
                color: AppColors.textSecondary,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatefulWidget {
  final String value;
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  const _InputField({
    required this.value,
    required this.hint,
    required this.onChanged,
    required this.onSubmitted,
  });

  @override
  State<_InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<_InputField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_InputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: const TextStyle(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w400,
        ),
        filled: false,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        isDense: true,
      ),
    );
  }
}
