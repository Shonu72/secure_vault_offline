package com.example.secure_vault_offline

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth requires FlutterFragmentActivity (not FlutterActivity)
// because biometric prompts use AndroidX Fragment under the hood.
class MainActivity : FlutterFragmentActivity()
