import 'package:flutter/material.dart';

class InputText extends StatelessWidget {
  final Function(String) onTextChanged;

  const InputText({super.key, required this.onTextChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onTextChanged,
      decoration: const InputDecoration(hintText: 'Say Something'),
    );
  }
}