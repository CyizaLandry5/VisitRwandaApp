// lib/main.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'sidebar.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Visit Rwanda',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const WebViewApp(),
      debugShowCheckedModeBanner: false,
    );
  }


}

class WebViewApp extends StatefulWidget {
  const WebViewApp({super.key});

  @override
  State<WebViewApp> createState() => _WebViewAppState();
}

final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
class _WebViewAppState extends State<WebViewApp> {
  WebViewController? _controller;
  bool _isConnected = true;
  bool _isLoading = true;
  int _selectedIndex = 0;
  String _appBarTitle = 'Home';

  final List<Map<String, String>> _pages = [
    {'title': 'Home', 'url': 'https://visitrwanda.com/'},
    {'title': 'Invest', 'url': 'https://visitrwanda.com/investment/'},
    {'title': 'Tourism', 'url': 'https://visitrwanda.com/tourism/'},
  ];

  @override
  void initState() {
    super.initState();
    _initWebView();
    _checkConnectivityAndLoad();
    _monitorConnectivity();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            if (error.isForMainFrame == true) {
              _controller!.loadHtmlString(_buildOfflineHtml());
              setState(() => _isLoading = false);
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      );
  }

  String _buildOfflineHtml() {
    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          body {
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            font-family: sans-serif;
            background: #fff;
            color: #555;
            text-align: center;
            padding: 24px;
          }
          .icon { font-size: 64px; margin-bottom: 16px; }
          h2 { font-size: 20px; font-weight: bold; color: #333; margin-bottom: 10px; }
          p { font-size: 15px; color: #777; line-height: 1.5; }
        </style>
      </head>
      <body>
        <div>
          <div class="icon">📡</div>
          <h2>No Internet Connection</h2>
          <p>Please connect to the internet<br>and try again.</p>
        </div>
      </body>
      </html>
    ''';
  }

  Future<void> _checkConnectivityAndLoad() async {
    final result = await Connectivity().checkConnectivity();
    final connected = result != ConnectivityResult.none;

    setState(() {
      _isConnected = connected;
      if (!connected) _isLoading = false;
    });

    if (connected) await _loadCurrentPage();
  }

  void _monitorConnectivity() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) async {
      final bool wasConnected = _isConnected;
      final bool nowConnected = result.first != ConnectivityResult.none;

      setState(() {
        _isConnected = nowConnected;
        if (!nowConnected) _isLoading = false;
      });

      if (nowConnected && !wasConnected) await _loadCurrentPage();
    });
  }

  Future<void> _loadCurrentPage() async {
    if (_controller == null) return;
    setState(() => _isLoading = true);
    await _controller!.loadRequest(Uri.parse(_pages[_selectedIndex]['url']!));
  }

  Future<void> _loadSidebarPage(String url, String title) async {
    if (_controller == null) return;
    setState(() {
      _appBarTitle = title;
      _isLoading = true;
    });
    await _controller!.loadRequest(Uri.parse(url));
  }

  void _onTabTapped(int index) async {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
      _appBarTitle = _pages[index]['title']!;
      _isLoading = true;
    });
    if (_isConnected) await _loadCurrentPage();
  }

  Future<void> _refresh() async {
    if (_isConnected && _controller != null) {
      await _controller!.reload();
    } else {
      await _checkConnectivityAndLoad();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(
          _appBarTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      drawer: SidebarDrawer(
        onItemSelected: (url, title) {
          if (_isConnected) _loadSidebarPage(url, title);
        },
      ),
      body: _buildBody(),   // ← full width now, no more Row
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: 'Invest'),
          BottomNavigationBarItem(icon: Icon(Icons.beach_access), label: 'Tourism'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (!_isConnected) return _buildNoInternetWidget();

    return Stack(
      children: [
        if (_controller != null)
          WebViewWidget(controller: _controller!),
        if (_isLoading)
          Container(
            color: Colors.white,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.green),
                  SizedBox(height: 20),
                  Text(
                    'Loading...',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNoInternetWidget() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 24),
              Text(
                'No Internet Connection',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Please check your internet connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _checkConnectivityAndLoad,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}