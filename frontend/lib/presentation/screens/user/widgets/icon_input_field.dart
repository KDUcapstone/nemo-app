import 'package:flutter/material.dart';
import 'package:frontend/app/theme/app_colors.dart';

class IconInputField extends StatefulWidget {
  final String hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final IconData icon;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final TextEditingController? controller;
  final bool enabled;

  const IconInputField({
    super.key,
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.controller,
    this.enabled = true,
  });

  @override
  State<IconInputField> createState() => _IconInputFieldState();
}

class _IconInputFieldState extends State<IconInputField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isFocused = _focusNode.hasFocus;
    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      onChanged: widget.onChanged,
      enabled: widget.enabled,
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: Icon(
          widget.icon,
          size: 20,
          color: widget.enabled
              ? AppColors.textSecondary
              : AppColors.textSecondary.withValues(alpha: 0.5),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 30,
          minHeight: 36,
        ),
        hintText: isFocused ? '' : widget.hintText,
        hintStyle: TextStyle(
          color: widget.enabled
              ? AppColors.textSecondary.withValues(alpha: 0.9)
              : AppColors.textSecondary.withValues(alpha: 0.5),
        ),
        filled: true,
        fillColor: widget.enabled ? Colors.white : Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: widget.enabled
                ? AppColors.divider
                : AppColors.divider.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.primary, width: 1.4),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.divider.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.4),
        ),
        errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
      ),
    );
  }
}
