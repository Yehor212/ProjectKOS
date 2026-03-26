# Performance Rules (Godot 4.6 Android)

1. Always use object pooling for repeating nodes (bullets, particles, UI elements)
2. Always call Tween.kill() before creating a new tween on the same property
3. Always set CPUParticles2D.emitting = false before queue_free()
4. Always use preload() for frequently used resources, load() for lazy
5. Always use texture atlas for related sprites (all animals, all foods)
6. Always keep draw calls < 50 per frame
7. Always keep total VRAM < 64MB, per scene < 16MB
8. Always keep CPUParticles2D.amount < 100 per emitter, max 3 emitters per scene
9. Always ensure orphan nodes = 0 (erase() from dict before queue_free())
10. Never call load() inside _process() or _physics_process()
