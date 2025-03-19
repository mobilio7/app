import 'package:flutter/material.dart';

Widget buildListView({
  required String title,
  required List<String> items,
  required bool isLoading,
  String? errorMessage,
}) {
  if (isLoading) {
    return Center(child: CircularProgressIndicator());
  }

  if (errorMessage != null) {
    return Center(
      child: Text(
        errorMessage,
        style: TextStyle(color: Colors.red, fontSize: 18),
      ),
    );
  }

  if (items.isEmpty) {
    return Center(
      child: Text(
        'No $title found.',
        style: TextStyle(fontSize: 18),
      ),
    );
  }

  return ListView.builder(
    itemCount: items.length,
    itemBuilder: (context, index) {
      return Card(
        elevation: 5,
        margin: EdgeInsets.symmetric(vertical: 8),
        child: ListTile(
          leading: Icon(Icons.list, color: Colors.blueGrey),
          title: Text(items[index],
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      );
    },
  );
}
