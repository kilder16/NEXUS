shader_type canvas_item;

// Vignette radial: rojo en bordes, transparente al centro.
// Controlado por uniform `intensity` (0=invisible, 1=máximo).

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 vignette_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(UV, center);
	// Inner radius 0.3 (transparent), outer 0.8 (full), smoothstep entre medio
	float vignette = smoothstep(0.3, 0.8, dist);
	COLOR = vec4(vignette_color.rgb, vignette_color.a * vignette * intensity);
}
