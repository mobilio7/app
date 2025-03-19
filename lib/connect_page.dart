import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'main_page.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class ConnectPage extends StatefulWidget {
  @override
  _ConnectPageState createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> with TickerProviderStateMixin {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  WebSocketChannel? channel;
  bool isConnecting = false;
  String? errorMessage;

  late AnimationController _fadeController;
  late AnimationController _iconAnimationController;

  late BannerAd _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _iconAnimationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true); // 아이콘 애니메이션 반복
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          print('배너 광고 로드 실패: $error');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _iconAnimationController.dispose();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void connectToRos2() {
    setState(() {
      isConnecting = true;
      errorMessage = null;
    });

    final ip = _ipController.text.trim();
    final port = _portController.text.trim();

    try {
      final uri = Uri.parse('ws://$ip:$port');
      channel = WebSocketChannel.connect(uri);
      setState(() {
        isConnecting = false;
      });

      Navigator.push(context, MaterialPageRoute(
        builder: (context) => MainPage(ip: ip, port: port, channel: channel!),
      ));

    } catch (e) {
      setState(() {
        errorMessage = 'Failed to connect: $e';
        isConnecting = false;
      });
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.help_outline, size: 50, color: Colors.blueAccent),
                SizedBox(height: 10),
                Text(
                  'Connection Guide',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                ),
                SizedBox(height: 10),
                Divider(color: Colors.grey),
                SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '1. ',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: 'Ensure the robot and device are on the same local network.\n',
                        style: TextStyle(color: Colors.black),
                      ),
                      TextSpan(
                        text: '2. ',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: 'Enter the IP address and port of the robot.\n',
                        style: TextStyle(color: Colors.black),
                      ),
                      TextSpan(
                        text: '3. ',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: 'Make sure ROS and rosbridge server are running on the robot.\n',
                        style: TextStyle(color: Colors.black),
                      ),
                      TextSpan(
                        text: '4. ',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: 'Press "Connect" to establish the connection.',
                        style: TextStyle(color: Colors.black),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Got it!'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.rocket, color: Colors.white),
            SizedBox(width: 10),
            Text('Connect to Robot'),
          ],
        ),
        backgroundColor: Colors.blueGrey,
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: <Widget>[
                    Text(
                      'Enter Connection Details',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    ),
                    SizedBox(height: 20),
                    AnimatedBuilder(
                      animation: _iconAnimationController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 + 0.05 * _iconAnimationController.value,
                          child: Icon(Icons.settings_input_antenna,
                              size: 100, color: Colors.blueGrey),
                        );
                      },
                    ),
                    SizedBox(height: 20),
                    Card(
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Network Status',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 10),
                            Text('Make sure ROS and rosbridge server are running on the robot.\nEnsure your device and robot are on the same local network'),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    TextField(
                      controller: _ipController,
                      decoration: InputDecoration(
                        labelText: 'Robot IP',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _portController,
                      decoration: InputDecoration(
                        labelText: 'Robot Port',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 20),
                    isConnecting
                        ? CircularProgressIndicator()
                        : ElevatedButton(
                      onPressed: connectToRos2,
                      child: Text('Connect'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Text(
                          errorMessage!,
                          style: TextStyle(color: Colors.redAccent, fontSize: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}