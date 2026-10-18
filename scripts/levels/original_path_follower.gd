extends RefCounted
class_name OriginalPathFollower

# PathFollower::Start/BeginSegment/Step, approach.cpp. Distances in source units,
# time in integer milliseconds and interpolation in 12-bit fixed point.
enum Result { ON_SEGMENT, NEXT_SEGMENT, END }
var points: Array[Vector3] = []
var speed = 0
var from_index = 0
var to_index = 1
var rate = 0
var fraction = 0
var position = Vector3.ZERO
var heading = 0.0

func start(source: Array, source_speed: float) -> void:
	points.clear()
	for p in source: points.append(Vector3(p[0],p[1],p[2]))
	speed = roundi(source_speed*100)
	from_index = 0
	to_index = 1
	position = points[0]
	_begin_segment()

func _begin_segment() -> void:
	var distance = int(points[from_index].distance_to(points[to_index]))
	var milliseconds = maxi(1,int(distance*1000.0/maxi(1,speed)))
	rate = int(4194304.0/milliseconds)
	fraction = 0
	var direction = points[from_index]-points[to_index]
	heading = -atan2(direction.x,direction.z)

func step(milliseconds: int) -> Result:
	position = points[from_index].lerp(points[to_index],fraction/4096.0)
	fraction += int(rate*milliseconds/1024.0)
	if fraction < 4096: return Result.ON_SEGMENT
	if to_index == points.size()-1:
		rate = 0
		return Result.END
	from_index += 1
	to_index += 1
	_begin_segment()
	return Result.NEXT_SEGMENT
