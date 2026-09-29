import 'package:flutter/material.dart';

class StallModel {
  final String name;
  final double rating;
  final String logoPath;
  final Color bgColor;

  StallModel({
    required this.name,
    required this.rating,
    required this.logoPath,
    required this.bgColor,
  });
}

class FoodModel {
  final String name;
  final String stallName;
  final double price;
  final double rating;
  final String imageUrl;

  FoodModel({
    required this.name,
    required this.stallName,
    required this.price,
    required this.rating,
    required this.imageUrl,
  });
}
