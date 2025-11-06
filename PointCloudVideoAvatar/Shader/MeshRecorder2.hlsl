#include "Rotation.hlsl"
#include "Codec.hlsl"
#include "VideoLayout.hlsl"

float _AutoHide;
float _Layer;
float _FOVSIZE;
float _NEAR;
float _FAR;
float _isOrtho;
static const float _PositionScale = 2;

struct VertInputTile {
	uint axis;
	float sign, slot;
	float4x4 mat0, mat1;
};
struct FragInputTile {
	nointerpolation ColorTile color : COLOR;
	float2 uv : TEXCOORD0;
	float4 pos : SV_Position;
	UNITY_VERTEX_OUTPUT_STEREO
};
float getFarClipDistanceOrtho()
{
	float C = UNITY_MATRIX_P[2][2];
	float D = UNITY_MATRIX_P[3][2];
	return -(D + 1.0) / C;
}
//Right handed system??
//float4 QuaternionFromMatrix(float3x3 m)
//{
//	float4 q;
//	float trace = m[0][0] + m[1][1] + m[2][2];
//
//	if (trace > 0.0) {
//		float s = sqrt(trace + 1.0) * 2.0;
//		q.w = 0.25 * s;
//		q.x = (m[2][1] - m[1][2]) / s;
//		q.y = (m[0][2] - m[2][0]) / s;
//		q.z = (m[1][0] - m[0][1]) / s;
//	}
//	else if (m[0][0] > m[1][1] && m[0][0] > m[2][2]) {
//		float s = sqrt(1.0 + m[0][0] - m[1][1] - m[2][2]) * 2.0;
//		q.w = (m[2][1] - m[1][2]) / s;
//		q.x = 0.25 * s;
//		q.y = (m[0][1] + m[1][0]) / s;
//		q.z = (m[0][2] + m[2][0]) / s;
//	}
//	else if (m[1][1] > m[2][2]) {
//		float s = sqrt(1.0 + m[1][1] - m[0][0] - m[2][2]) * 2.0;
//		q.w = (m[0][2] - m[2][0]) / s;
//		q.x = (m[0][1] + m[1][0]) / s;
//		q.y = 0.25 * s;
//		q.z = (m[1][2] + m[2][1]) / s;
//	}
//	else {
//		float s = sqrt(1.0 + m[2][2] - m[0][0] - m[1][1]) * 2.0;
//		q.w = (m[1][0] - m[0][1]) / s;
//		q.x = (m[0][2] + m[2][0]) / s;
//		q.y = (m[1][2] + m[2][1]) / s;
//		q.z = 0.25 * s;
//	}
//	return q;
//}
float4 QuaternionFromMatrix(float3x3 m)
{
	float4 q;
	float trace = m[0][0] + m[1][1] + m[2][2];

	if (trace > 0.0) {
		float s = sqrt(trace + 1.0) * 2.0;
		q.w = 0.25 * s;
		q.x = (m[1][2] - m[2][1]) / s; // flipped
		q.y = (m[2][0] - m[0][2]) / s; // flipped
		q.z = (m[0][1] - m[1][0]) / s; // flipped
	}
	else if (m[0][0] > m[1][1] && m[0][0] > m[2][2]) {
		float s = sqrt(1.0 + m[0][0] - m[1][1] - m[2][2]) * 2.0;
		q.w = (m[1][2] - m[2][1]) / s; // flipped
		q.x = 0.25 * s;
		q.y = (m[0][1] + m[1][0]) / s;
		q.z = (m[0][2] + m[2][0]) / s;
	}
	else if (m[1][1] > m[2][2]) {
		float s = sqrt(1.0 + m[1][1] - m[0][0] - m[2][2]) * 2.0;
		q.w = (m[2][0] - m[0][2]) / s; // flipped
		q.x = (m[0][1] + m[1][0]) / s;
		q.y = 0.25 * s;
		q.z = (m[1][2] + m[2][1]) / s;
	}
	else {
		float s = sqrt(1.0 + m[2][2] - m[0][0] - m[1][1]) * 2.0;
		q.w = (m[0][1] - m[1][0]) / s; // flipped
		q.x = (m[0][2] + m[2][0]) / s;
		q.y = (m[1][2] + m[2][1]) / s;
		q.z = 0.25 * s;
	}
	return q;
}
float4 EncodeTransform(VertInputTile i, inout FragInputTile o) {
	// pos, rot, scale
	float3 rotY = i.mat1.c1;
	float3 rotZ = i.mat1.c2;
	float3 pos  = i.mat1.c3 - i.mat0.c3;
	pos  = mul(transpose(i.mat0), pos)  / dot(i.mat0.c1, i.mat0.c1);
	rotY = mul(transpose(i.mat0), rotY) / dot(i.mat0.c1, i.mat0.c1);
	rotZ = mul(transpose(i.mat0), rotZ) / dot(i.mat0.c1, i.mat0.c1);
	float scale = length(rotY);
	rotY = normalize(rotY);
	rotZ = normalize(rotZ);

	// data
	float data;
	if(i.axis < 3) {
		float3x3 rot;
		rot.c1 = rotY;
		rot.c2 = rotZ;
		rot.c0 = cross(rot.c1, rot.c2);
		data = swingTwistAngles(rot)[i.axis] / UNITY_PI / i.sign;
	}
	//else if (i.axis < 9)
	//{
	//	// position (unchanged)
	//	data = pos[i.axis - (i.axis < 6 ? 3 : 6)] / _PositionScale;
	//}
	//else if (i.axis < 10)
	//{
	//	// Quaternion from rotation matrix (world space)
	//	float3x3 rotMatrix;
	//	rotMatrix[0] = normalize(i.mat1.c0.xyz);
	//	rotMatrix[1] = normalize(i.mat1.c1.xyz);
	//	rotMatrix[2] = normalize(i.mat1.c2.xyz);
	//	float4 q = QuaternionFromMatrix(rotMatrix);

	//	// Encode quaternion components in slots 6–9
	//	uint qIndex = i.axis - 6;
	//	data = q[qIndex]; // q.x, q.y, q.z, q.w (all between -1 and 1)
	//}
	else if(i.axis < 9)
		data = pos[i.axis-(i.axis < 6 ? 3 : 6)]/ _PositionScale;
	else if(i.axis < 12)
		data = rotY[i.axis - 9] * min(1, scale);
	else
		data = rotZ[i.axis-12] * min(1, rcp(scale));

	// color, rect
	float4 rect = GetTileRect(uint(i.slot));

	float3x3 rotMatrix;
	rotMatrix[0] = normalize(i.mat1.c0.xyz);
	rotMatrix[1] = normalize(i.mat1.c1.xyz);
	rotMatrix[2] = normalize(i.mat1.c2.xyz);
	float4 q = QuaternionFromMatrix(rotMatrix);

	if (uint(i.slot) == 6) 
	{
		data = q.x;
	}
	if (uint(i.slot) == 7)
	{
		data = q.y;
	}
	if (uint(i.slot) == 8)
	{
		data = q.z;
	}
	if (uint(i.slot) == 9)
	{
		data = q.w;
	}

	if (uint(i.slot) == 10) {
		data = _FOVSIZE;
	}
	if (uint(i.slot) == 11) {
		data = _FOVSIZE;
	}

	if (uint(i.slot) == 12) {
		data = _NEAR;
	}
	if (uint(i.slot) == 13) {
		data = _NEAR;
	}

	if (uint(i.slot) == 14) {
		data = _FAR;
	}
	if (uint(i.slot) == 15) {
		data = _FAR;
	}
	if (uint(i.slot) == 16) {
		data = _isOrtho;
	}

	if (uint(i.slot) > 16) {
		data = 0.0;
	}

	if(i.slot < 0) // background
		rect = layerRect, data = 0;
	EncodeVideoSnorm(o.color, data, (i.axis >= 3 && i.axis < 6) || i.slot==10 || i.slot == 12 || i.slot == 14);

	

	// pos
	uint layer = _Layer;
	rect.xz += layer/2 * layerRect.z;
	if(layer & 1)
		rect.xz = 1-rect.xz;

	float2 screenSize = _ScreenParams.xy/2;
	rect = round(rect * screenSize.xyxy) / screenSize.xyxy;
	rect = rect*2-1;
	#if !defined(_REQUIRE_UV2)
		rect.yw *= _ProjectionParams.x;
	#elif UNITY_UV_STARTS_AT_TOP
		rect.yw *= -1;
	#endif

	o.pos = float4(0, 0, UNITY_NEAR_CLIP_VALUE, 1);
	#if !defined(_REQUIRE_UV2)
		#if defined(USING_STEREO_MATRICES)
			return 0; // hide in VR
		#endif
		if(any(UNITY_MATRIX_P[2].xy))
			return 0; // hide in mirror (near plane normal != Z axis)
		if(_AutoHide && _ProjectionParams.z != 0)
			return 0;
	#endif

	//float farClip = getFarClipDistanceOrtho();
	//if (abs(farClip - 0.25) > 0.1) // only show if far clip is about 25 units
	//	return 0;
	
	float orthoSize = 1.0 / UNITY_MATRIX_P[1][1];
	if (abs(orthoSize - 0.05) > 0.1) {
		return 0;
	}

	return rect;
}
float4 fragTile(FragInputTile i) : SV_Target {
	return RenderTile(i.color, i.uv);
}