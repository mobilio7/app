import 'package:flutter/material.dart';
import 'pages/node_list_page.dart';
import 'pages/topic_list_page.dart';
import 'pages/service_list_page.dart';

class WebSocketPage extends StatefulWidget {
  final String ip;
  final String port;

  WebSocketPage({required this.ip, required this.port});

  @override
  _WebSocketPageState createState() => _WebSocketPageState();
}

class _WebSocketPageState extends State<WebSocketPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ROS List Viewer'),
        backgroundColor: Colors.blueGrey,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            Tab(icon: Icon(Icons.device_hub), text: 'Nodes'),
            Tab(icon: Icon(Icons.topic), text: 'Topics'),
            Tab(icon: Icon(Icons.settings), text: 'Services'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          NodeListPage(ip: widget.ip, port: widget.port),
          TopicListPage(ip: widget.ip, port: widget.port),
          ServiceListPage(ip: widget.ip, port: widget.port),
        ],
      ),
    );
  }
}
