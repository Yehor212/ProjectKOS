# Platform Compatibility Rules (Android)

1. Always use `gl_compatibility` renderer (LAW 18)
2. Always use CPUParticles2D (GPUParticles2D unsupported on low-end Android)
3. Always design for landscape 1280x720 with stretch mode "canvas_items"
4. Always apply safe area margins on edge-touching elements
5. Always keep `export_presets.cfg` in .gitignore (security)
6. Always test touch input (emulate_touch_from_mouse enabled)
7. Always target arm64-v8a architecture
8. Always keep total APK assets under 64MB
