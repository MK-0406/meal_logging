import 'package:flutter/material.dart';

class InputTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool isNumber;
  final bool isInt;
  final bool includeZero;

  const InputTextField({super.key,
    required this.label,
    required this.controller,
    required this.isNumber,
    required this.isInt,
    this.includeZero = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 15),
        contentPadding: EdgeInsets.symmetric(vertical: 13, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter ${label.toLowerCase()}';
        } else if (isNumber){
          if (isInt) {
            if (int.tryParse(value) == null) {
              return '$label must be an integer';
            }
          } else {
            if (double.tryParse(value) == null) {
              return '$label must be a number';
            }
          }
          if (includeZero) {
            if (double.parse(value) < 0) {
              return '$label must be 0 or above';
            }
          } else {
            if (double.parse(value) <= 0) {
              return '$label must be greater than 0';
            }
          }
        }
        return null;
      }
    );
  }
}

class CustomFormText extends StatelessWidget {
  final String text;

  const CustomFormText({super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }
}


