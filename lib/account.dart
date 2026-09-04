import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart'; // contains supabase instance

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  bool isLogin = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> submitAuth() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => isLoading = true);
    
    try {
      if (isLogin) {
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } else {
        await supabase.auth.signUp(
          email: email,
          password: password,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created successfully!')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('AuthException: ', '')), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  Widget _buildAuthScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Icon(Icons.lock_outline_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 24),
          Text(
            isLogin ? "Welcome Back" : "Create Account", 
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5), 
            textAlign: TextAlign.center
          ),
          const SizedBox(height: 8),
          Text(
            isLogin ? "Sign in to access your orders and wishlist." : "Sign up to start shopping and saving your favorites.",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          
          // Form
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200)
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: "Email Address",
                    border: InputBorder.none,
                    icon: Icon(Icons.email_outlined, color: Colors.grey),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const Divider(),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: "Password",
                    border: InputBorder.none,
                    icon: Icon(Icons.lock_outline, color: Colors.grey),
                  ),
                  obscureText: true,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: isLoading ? null : submitAuth,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black, 
                foregroundColor: Colors.white, 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0
              ),
              child: isLoading 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : Text(isLogin ? "SIGN IN" : "CREATE ACCOUNT", style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
          
          const SizedBox(height: 24),
          
          TextButton(
            onPressed: () {
              setState(() {
                isLogin = !isLogin;
                emailController.clear();
                passwordController.clear();
              });
            },
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade800),
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                children: [
                  TextSpan(text: isLogin ? "Don't have an account? " : "Already have an account? "),
                  TextSpan(text: isLogin ? "Sign Up" : "Log In", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                ]
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildProfileScreen(User user) {
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.grey.shade200,
              child: const Icon(Icons.person, size: 30, color: Colors.grey),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Hello,", style: TextStyle(color: Colors.grey, fontSize: 14)),
                  Text(user.email ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.red),
              onPressed: signOut,
              tooltip: "Logout",
            )
          ],
        ),
        const SizedBox(height: 40),
        
        // Profile Options
        _buildProfileOption(Icons.location_on_outlined, "Shipping Addresses"),
        const Divider(),
        _buildProfileOption(Icons.payment_outlined, "Payment Methods"),
        const Divider(),
        _buildProfileOption(Icons.notifications_outlined, "Notifications"),
        const Divider(),
        _buildProfileOption(Icons.help_outline, "Help & Support"),
      ],
    );
  }

  Widget _buildProfileOption(IconData icon, String title) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: Colors.black87),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('MY ACCOUNT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<AuthState>(
        stream: supabase.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = supabase.auth.currentSession;
          if (session == null) {
            return _buildAuthScreen();
          }
          return _buildProfileScreen(session.user);
        },
      ),
    );
  }
}
