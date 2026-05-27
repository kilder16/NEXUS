"""
Procesa los 4 FBX del Swat Guy (Mixamo) y los combina en un solo GLB.

Lee:
  - idle.fbx (modelo + animación idle, con malla y texturas)
  - walk.fbx (solo animación walk, sin malla)
  - attack.fbx (solo animación attack, sin malla)
  - death.fbx (solo animación death, sin malla)

Produce:
  - boss.glb: modelo Swat Guy con 4 animaciones (idle/walk/attack/death)
              en un solo archivo. Texturas embedded, formato moderno
              optimizado para Godot 4.

Uso desde terminal (Windows PowerShell o CMD):
  & "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" --background --python build_boss_glb.py

El script asume que el .py está en la misma carpeta que los FBX.
"""

import bpy
import os
import sys

# ============================================================
# CONFIGURACIÓN
# ============================================================

# Carpeta donde están los FBX (la misma donde corre el script).
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

FBX_IDLE = os.path.join(SCRIPT_DIR, "idle.fbx")
FBX_WALK = os.path.join(SCRIPT_DIR, "walk.fbx")
FBX_ATTACK = os.path.join(SCRIPT_DIR, "attack.fbx")
FBX_DEATH = os.path.join(SCRIPT_DIR, "death.fbx")

OUTPUT_GLB = os.path.join(SCRIPT_DIR, "boss.glb")

# Nombres con los que se renombrarán las animaciones (lo que Godot va a ver).
ANIM_NAMES = {
    FBX_IDLE: "idle",
    FBX_WALK: "walk",
    FBX_ATTACK: "attack",
    FBX_DEATH: "death",
}

# ============================================================
# HELPERS
# ============================================================

def log(msg):
    print(f"[BUILD_BOSS] {msg}", flush=True)


def clear_scene():
    """Borra todo de la escena por defecto de Blender (incluye el cubo, luces, cámara)."""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    # También borrar datos huérfanos.
    for block in bpy.data.meshes:
        bpy.data.meshes.remove(block)
    for block in bpy.data.materials:
        bpy.data.materials.remove(block)
    for block in bpy.data.armatures:
        bpy.data.armatures.remove(block)
    for block in bpy.data.actions:
        bpy.data.actions.remove(block)


def import_fbx(filepath):
    """Importa un FBX y retorna las objects nuevas que aparecieron."""
    objs_before = set(bpy.data.objects)
    actions_before = set(bpy.data.actions)
    bpy.ops.import_scene.fbx(filepath=filepath)
    objs_new = set(bpy.data.objects) - objs_before
    actions_new = set(bpy.data.actions) - actions_before
    return objs_new, actions_new


def find_armature(objects):
    """Encuentra el primer Armature en una colección de objects."""
    for obj in objects:
        if obj.type == 'ARMATURE':
            return obj
    return None


# ============================================================
# PIPELINE PRINCIPAL
# ============================================================

def main():
    log("Iniciando build del boss.glb")
    log(f"Carpeta de trabajo: {SCRIPT_DIR}")

    # Validar que existan los 4 FBX.
    for fbx in [FBX_IDLE, FBX_WALK, FBX_ATTACK, FBX_DEATH]:
        if not os.path.exists(fbx):
            log(f"ERROR: no existe {fbx}")
            sys.exit(1)
        size_mb = os.path.getsize(fbx) / (1024 * 1024)
        log(f"  Encontrado: {os.path.basename(fbx)} ({size_mb:.1f} MB)")

    # Limpiar la escena default de Blender.
    log("Limpiando escena default...")
    clear_scene()

    # Importar idle.fbx (trae el modelo, esqueleto, y la animación idle).
    log(f"Importando {os.path.basename(FBX_IDLE)} (modelo + idle)...")
    idle_objs, idle_actions = import_fbx(FBX_IDLE)
    main_armature = find_armature(idle_objs)
    if main_armature is None:
        log("ERROR: idle.fbx no tiene Armature. ¿Se descargó con 'With Skin'?")
        sys.exit(1)
    log(f"  Armature principal: {main_armature.name}")
    log(f"  Acciones importadas: {[a.name for a in idle_actions]}")

    # Renombrar la acción idle.
    if idle_actions:
        idle_action = list(idle_actions)[0]
        idle_action.name = "idle"
        # Asegurar que la acción tenga fake_user para que se exporte.
        idle_action.use_fake_user = True
        log("  Acción 'idle' renombrada y marcada con fake_user.")

    # Importar las otras 3 animaciones, una por una.
    # De cada FBX, tomar solo las acciones (la animación) y descartar el
    # esqueleto/malla importados.
    for fbx_path in [FBX_WALK, FBX_ATTACK, FBX_DEATH]:
        anim_name = ANIM_NAMES[fbx_path]
        log(f"Importando {os.path.basename(fbx_path)} (animación {anim_name})...")
        new_objs, new_actions = import_fbx(fbx_path)
        if not new_actions:
            log(f"  WARN: {fbx_path} no aportó acciones nuevas. Saltando.")
        else:
            # Renombrar y marcar fake_user.
            action = list(new_actions)[0]
            action.name = anim_name
            action.use_fake_user = True
            log(f"  Acción '{anim_name}' renombrada y marcada con fake_user.")
        # Borrar el Armature/Mesh duplicados que vinieron en este FBX.
        # Solo queremos las acciones; la malla y el esqueleto ya están del idle.
        for obj in new_objs:
            bpy.data.objects.remove(obj, do_unlink=True)
        log(f"  Limpiados {len(new_objs)} objects duplicados del import.")

    # Re-asignar todas las acciones al main_armature para que se exporten todas.
    # En Blender, las acciones se exportan a GLB si están asignadas a algún
    # NLA track del armature O si tienen fake_user. Marcamos fake_user arriba,
    # pero además vamos a agregar a NLA tracks para robustez.
    log("Asignando acciones al NLA del armature principal...")
    if main_armature.animation_data is None:
        main_armature.animation_data_create()

    # Limpiar NLA tracks viejos.
    while main_armature.animation_data.nla_tracks:
        main_armature.animation_data.nla_tracks.remove(
            main_armature.animation_data.nla_tracks[0]
        )

    # Crear un NLA track por cada acción.
    for action_name in ["idle", "walk", "attack", "death"]:
        action = bpy.data.actions.get(action_name)
        if action is None:
            log(f"  WARN: no se encontró acción '{action_name}'. Saltando.")
            continue
        track = main_armature.animation_data.nla_tracks.new()
        track.name = action_name
        strip = track.strips.new(action_name, int(action.frame_range[0]), action)
        log(f"  NLA track '{action_name}' agregado.")

    # Limpiar la acción activa (sino al exportar se duplica la primera).
    main_armature.animation_data.action = None

    # Resumen pre-export.
    log("Resumen pre-export:")
    log(f"  Total objects: {len(bpy.data.objects)}")
    log(f"  Total meshes: {len(bpy.data.meshes)}")
    log(f"  Total materials: {len(bpy.data.materials)}")
    log(f"  Total images: {len(bpy.data.images)}")
    log(f"  Total actions: {len(bpy.data.actions)}")
    log(f"  NLA tracks: {len(main_armature.animation_data.nla_tracks)}")

    # Exportar a GLB.
    log(f"Exportando a {OUTPUT_GLB}...")
    bpy.ops.export_scene.gltf(
        filepath=OUTPUT_GLB,
        export_format='GLB',
        # Embed all (texturas dentro del GLB).
        export_image_format='AUTO',
        # Animaciones.
        export_animations=True,
        export_animation_mode='NLA_TRACKS',
        export_nla_strips=True,
        # Skin / armature.
        export_skins=True,
        # Generales.
        export_apply=True,
        use_visible=False,
        use_renderable=False,
        use_active_collection=False,
        # Calidad máxima de texturas (vos pediste 4K).
        export_jpeg_quality=100,
    )

    # Validar resultado.
    if not os.path.exists(OUTPUT_GLB):
        log("ERROR: el GLB no se generó.")
        sys.exit(1)

    size_mb = os.path.getsize(OUTPUT_GLB) / (1024 * 1024)
    log("===========================================")
    log(f"✓ boss.glb generado: {size_mb:.2f} MB")
    log(f"  Path: {OUTPUT_GLB}")
    log("===========================================")
    log("Animaciones incluidas: idle, walk, attack, death")
    log("Listo para importar a Godot. Cerrá Blender (auto-cerrar en --background).")


if __name__ == "__main__":
    main()
