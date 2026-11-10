import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class AppTextField extends StatelessWidget {
  final String? label;
  final String? hintText;
  final String? errorText;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final IconData? prefixIcon;
  final String? prefixText;
  final Widget? suffixIcon;
  final int? maxLines;
  final bool useFormField;

  const AppTextField({
    super.key,
    this.label,
    this.hintText,
    this.errorText,
    this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.validator,
    this.prefixIcon,
    this.prefixText,
    this.suffixIcon,
    this.maxLines = 1,
    this.useFormField = true,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
      errorText: errorText,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      isDense: true,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 20, color: AppColors.textSlate)
          : null,
      prefixText: prefixText,
      prefixStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.brandRed, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.statusRedText),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
        ],
        useFormField
            ? TextFormField(
                controller: controller,
                obscureText: obscureText,
                keyboardType: keyboardType,
                onChanged: onChanged,
                validator: validator,
                maxLines: maxLines,
                style: const TextStyle(fontSize: 14, color: AppColors.textDark),
                decoration: decoration,
              )
            : TextField(
                controller: controller,
                obscureText: obscureText,
                keyboardType: keyboardType,
                onChanged: onChanged,
                maxLines: maxLines,
                style: const TextStyle(fontSize: 14, color: AppColors.textDark),
                decoration: decoration,
              ),
      ],
    );
  }
}

class AppSearchField extends StatelessWidget {
  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final double width;

  const AppSearchField({
    super.key,
    this.hintText = 'Search...',
    this.controller,
    this.onChanged,
    this.onClear,
    this.width = 240,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 36,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          prefixIcon: const Icon(
            Icons.search,
            size: 18,
            color: AppColors.textSlate,
          ),
          suffixIcon: controller?.text.isNotEmpty == true
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () {
                    controller?.clear();
                    onClear?.call();
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.brandRed, width: 1.5),
          ),
        ),
      ),
    );
  }
}
