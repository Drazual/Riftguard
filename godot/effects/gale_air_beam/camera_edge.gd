class_name GaleBeamCameraEdge
extends RefCounted
## Intersect a world ray with the actual camera's four SIDE frustum planes.
## Works in perspective and orthographic, including camera offsets / viewport aspect.
## Ray is at muzzle height; pass a horizontal direction for a horizontal beam.
## 0 means invalid / starting offscreen / no finite forward exit. Caller must handle it.
static func length_to_edge(camera: Camera3D, origin: Vector3, direction: Vector3, overscan_m: float = 0.0) -> float:
 if camera == null or direction.length_squared() < 0.000001:
  return 0.0
 if camera.is_position_behind(origin): return 0.0
 var rect := camera.get_viewport().get_visible_rect()
 if not rect.has_point(camera.unproject_position(origin)): return 0.0
 var d := direction.normalized()
 var result: float = INF
 var planes := camera.get_frustum()
 # Godot order: near, far, left, top, right, bottom.
 for i in range(2,6):
  var p: Plane = planes[i]
  var denom := p.normal.dot(d)
  if absf(denom) < 0.000001: continue
  var t := -p.distance_to(origin)/denom
  if t >= 0.0: result = minf(result,t)
 if is_inf(result): return 0.0
 return maxf(0.0,result+overscan_m)
