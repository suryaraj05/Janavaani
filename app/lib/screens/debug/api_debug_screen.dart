import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../widgets/bottom_nav_bar.dart';

class ApiDebugScreen extends StatefulWidget {
  const ApiDebugScreen({super.key});

  @override
  State<ApiDebugScreen> createState() => _ApiDebugScreenState();
}

class _ApiDebugScreenState extends State<ApiDebugScreen> {
  String _testResult = '';
  bool _isTesting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Debug'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // API Configuration
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'API Configuration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Base URL', ApiConfig.baseUrl),
                    _buildInfoRow('Firebase user', FirebaseAuth.instance.currentUser?.email ?? '(not signed in)'),
                    _buildInfoRow('Firebase uid', FirebaseAuth.instance.currentUser?.uid ?? '—'),
                    _buildInfoRow('API Version', ApiConfig.apiVersion),
                    _buildInfoRow('Health Endpoint', ApiConfig.health),
                    _buildInfoRow('Login Endpoint', ApiConfig.authLogin),
                    _buildInfoRow('Config Endpoint', ApiConfig.config),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Test Buttons
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test Endpoints',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isTesting ? null : _testHealth,
                      icon: const Icon(Icons.health_and_safety),
                      label: const Text('Test Health Check'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _isTesting ? null : _testVersion,
                      icon: const Icon(Icons.info),
                      label: const Text('Test Version Info'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _isTesting ? null : _testConfig,
                      icon: const Icon(Icons.settings),
                      label: const Text('Test Config'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _isTesting ? null : _testAuthMe,
                      icon: const Icon(Icons.person),
                      label: const Text('Test /auth/me'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _isTesting ? null : _showToken,
                      icon: const Icon(Icons.key),
                      label: const Text('Show Firebase Token'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Test Results
            if (_testResult.isNotEmpty)
              Card(
                color: Colors.grey[900],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Test Result',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        _testResult,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(currentRoute: '/debug'),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testHealth() async {
    setState(() {
      _isTesting = true;
      _testResult = 'Testing health endpoint...\n';
    });

    try {
      final apiService = ApiService();
      apiService.init();
      final response = await apiService.healthCheck();
      
      setState(() {
        _testResult = '✅ Health Check Success!\n\n'
            'Status: ${response.statusCode}\n'
            'Response: ${response.data}';
      });
    } catch (e) {
      setState(() {
        _testResult = '❌ Health Check Failed!\n\n'
            'Error: ${e.toString()}\n\n'
            'Full URL: ${ApiConfig.baseUrl}${ApiConfig.health}';
      });
    } finally {
      setState(() => _isTesting = false);
    }
  }

  Future<void> _testVersion() async {
    setState(() {
      _isTesting = true;
      _testResult = 'Testing version endpoint...\n';
    });

    try {
      final apiService = ApiService();
      apiService.init();
      final response = await apiService.getVersionInfo();
      
      setState(() {
        _testResult = '✅ Version Info Success!\n\n'
            'Status: ${response.statusCode}\n'
            'Response: ${response.data}';
      });
    } catch (e) {
      setState(() {
        _testResult = '❌ Version Info Failed!\n\n'
            'Error: ${e.toString()}\n\n'
            'Full URL: ${ApiConfig.baseUrl}${ApiConfig.version}';
      });
    } finally {
      setState(() => _isTesting = false);
    }
  }

  Future<void> _testConfig() async {
    setState(() {
      _isTesting = true;
      _testResult = 'Testing config endpoint...\n';
    });

    try {
      final apiService = ApiService();
      apiService.init();
      final response = await apiService.getConfig();
      
      setState(() {
        _testResult = '✅ Config Success!\n\n'
            'Status: ${response.statusCode}\n'
            'Response: ${response.data}';
      });
    } catch (e) {
      setState(() {
        _testResult = '❌ Config Failed!\n\n'
            'Error: ${e.toString()}\n\n'
            'Full URL: ${ApiConfig.baseUrl}${ApiConfig.config}';
      });
    } finally {
      setState(() => _isTesting = false);
    }
  }

  Future<void> _testAuthMe() async {
    setState(() {
      _isTesting = true;
      _testResult = 'Testing /auth/me...\n';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _testResult = '❌ Not signed in — login first, then retry.';
        });
        return;
      }

      final apiService = ApiService();
      apiService.init();
      final response = await apiService.getCurrentUser();

      setState(() {
        _testResult = '✅ /auth/me Success!\n\n'
            'Status: ${response.statusCode}\n'
            'Response: ${response.data}';
      });
    } catch (e) {
      setState(() {
        _testResult = '❌ /auth/me Failed!\n\n'
            'Error: $e\n\n'
            'Full URL: ${ApiConfig.baseUrl}${ApiConfig.authMe}';
      });
    } finally {
      setState(() => _isTesting = false);
    }
  }

  Future<void> _showToken() async {
    setState(() {
      _isTesting = true;
      _testResult = 'Getting Firebase token...\n';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _testResult = '❌ No user logged in!\n\n'
              'Please login first to get your token.';
        });
        return;
      }

      // Get fresh token
      final token = await user.getIdToken(false);
      
      setState(() {
        _testResult = '🔑 Firebase ID Token:\n\n'
            '${token}\n\n'
            '📋 User Info:\n'
            'UID: ${user.uid}\n'
            'Email: ${user.email ?? "N/A"}\n'
            'Display Name: ${user.displayName ?? "N/A"}\n\n'
            '💡 Copy this token and use it to test the API:\n'
            'node test-api-simple.js "$token"';
      });
    } catch (e) {
      setState(() {
        _testResult = '❌ Error getting token!\n\n'
            'Error: ${e.toString()}';
      });
    } finally {
      setState(() => _isTesting = false);
    }
  }
}

