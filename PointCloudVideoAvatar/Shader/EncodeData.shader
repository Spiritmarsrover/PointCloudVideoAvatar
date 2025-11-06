Shader "Custom/EncodeData"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}

		_VisibleSlotCount("Visible Slots", Range(0,135)) = 135

		_PosX("X", Float) = 0.0
		_PosY("Y", Float) = 0.0
		_PosZ("Z", Float) = 0.0

		_QuaterionX("Rotation Quaterion", Float) = 0.0
		_QuaterionY("Rotation Quaterion", Float) = 0.0
		_QuaterionZ("Rotation Quaterion", Float) = 0.0
		_QuaterionW("Rotation Quaterion", Float) = 0.0
			/*_RotY("Transform local Y", Vector) = (0.0, 0.0, 0.0)
			_RotZ("Transform local Z", Vector) = (0.0, 0.0, 0.0)*/

			_FOVSIZE("FOV/SIZE", Float) = 0.0

			_NEAR("Near Plane", Float) = 0.0
			_FAR("Far Plane", Float) = 0.0
			[ToggleUI] _isOrtho("Is Ortho?",Float) = 1.0
			//_FOVSIZEY("FOV/SIZE", Float) = 0.0
			//_FOVSIZEZ("FOV/SIZE", Float) = 0.0
			//_Scale("Scale", Float) = 1.0
	}
		SubShader
		{
			Tags { "QUEUE" = "Transparent" "IGNOREPROJECTOR" = "true" "RenderType" = "Transparent" }
			//Tags { "RenderType" = "Opaque" }
			ZWrite Off
			Blend SrcAlpha OneMinusSrcAlpha
			Cull back
			LOD 100
			LOD 100

			Pass
			{
				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				// make fog work
				#pragma multi_compile_fog
			
				#include <UnityCG.cginc>
				#include "Codec.hlsl"
				#include "VideoLayout.hlsl"
				#include "Rotation.hlsl"
				//#include "MeshRecorder.hlsl"

				float _PosX;
				float _PosY;
				float _PosZ;
				float _QuaterionX;
				float _QuaterionY;
				float _QuaterionZ;
				float _QuaterionW;
				//float3 _RotY;
				//float3 _RotZ;
				//float _Scale;
				int _VisibleSlotCount;
				float _FOVSIZE;
				float _NEAR;
				float _FAR;
				float _isOrtho;

				struct appdata
				{
					float4 vertex : POSITION;
					float2 uv : TEXCOORD0;
				};

				struct v2f
				{
					float2 uv : TEXCOORD0;
					UNITY_FOG_COORDS(1)
					float4 vertex : SV_POSITION;
				};
				struct FragInputTile {
					nointerpolation ColorTile color : COLOR;
					float2 uv : TEXCOORD0;
					float4 pos : SV_Position;
					UNITY_VERTEX_OUTPUT_STEREO
				};


				//Structs for Skinnedmeshrenderer
				// Input structs for vertex, geometry, and fragment stages
				struct VertInput {
					float3 vertex  : POSITION;
					float3 normal  : NORMAL;
					float4 tangent : TANGENT;
					float2 uv      : TEXCOORD0;
					UNITY_VERTEX_INPUT_INSTANCE_ID
				};

				struct GeomInput {
					float3 vertex  : TEXCOORD0;
					float3 normal  : TEXCOORD1;
					float4 tangent : TEXCOORD2;
					float2 uv      : TEXCOORD3;
					UNITY_VERTEX_INPUT_INSTANCE_ID
				};

				// Builds a local transform matrix from vertex position, normal, and tangent
				float4x4 getMatrix(GeomInput i) {
					float4x4 m;
					m.c0 = cross(normalize(i.normal), i.tangent.xyz); // local X axis
					m.c1 = i.normal;                                  // local Y axis
					m.c2 = i.tangent.xyz;                             // local Z axis
					m.c3 = i.vertex;                                  // position
					m._41_42_43_44 = float4(0, 0, 0, 1);                 // homogeneous row
					return m;
				}

				//Builds a Quaternion from the matrix
				float4 QuaternionFromMatrix(float4x4 m) {
					float4 q;
					float trace = m._11 + m._22 + m._33;

					if (trace > 0.0) {
						float s = sqrt(trace + 1.0) * 2.0;
						q.w = 0.25 * s;
						q.x = (m._32 - m._23) / s;
						q.y = (m._13 - m._31) / s;
						q.z = (m._21 - m._12) / s;
					}
					else if (m._11 > m._22 && m._11 > m._33) {
						float s = sqrt(1.0 + m._11 - m._22 - m._33) * 2.0;
						q.w = (m._32 - m._23) / s;
						q.x = 0.25 * s;
						q.y = (m._12 + m._21) / s;
						q.z = (m._13 + m._31) / s;
					}
					else if (m._22 > m._33) {
						float s = sqrt(1.0 + m._22 - m._11 - m._33) * 2.0;
						q.w = (m._13 - m._31) / s;
						q.x = (m._12 + m._21) / s;
						q.y = 0.25 * s;
						q.z = (m._23 + m._32) / s;
					}
					else {
						float s = sqrt(1.0 + m._33 - m._11 - m._22) * 2.0;
						q.w = (m._21 - m._12) / s;
						q.x = (m._13 + m._31) / s;
						q.y = (m._23 + m._32) / s;
						q.z = 0.25 * s;
					}
					return normalize(q);
				}


				sampler2D _MainTex;
				float4 _MainTex_ST;

				v2f vert(appdata v)
				{
					v2f o;
					o.vertex = UnityObjectToClipPos(v.vertex);
					o.uv = TRANSFORM_TEX(v.uv, _MainTex);
					UNITY_TRANSFER_FOG(o,o.vertex);
					return o;
				}
				float4 LinearToGammaCustom(float4 linearColor) {
					return pow(linearColor, 2.2);
				}
				fixed4 frag(v2f i) : SV_Target
				{
					// sample the texture
					//fixed4 col = tex2D(_MainTex, i.uv);
					// apply fog
					//UNITY_APPLY_FOG(i.fogCoord, col);

					const int cols = 3;
					const int rows = 45;
					const float slotWidth = 0.16667;
					const float slotHeight = 1.0 / rows;

					float2 uvRemap = i.uv;
					float2 localUV = uvRemap;

					// Determine which slot this UV would fall into
					int col = (int)(localUV.x / (2.0 * slotWidth));
					int row = (int)((1.0 - localUV.y) / slotHeight);

					// Compute slot index in top-to-bottom, left-to-right order
					int slotIndex = col * rows + row;

					// UV within the slot
					float2 inSlotUV = float2(fmod(localUV.x, 2.0 * slotWidth), fmod(localUV.y, slotHeight));
					bool inSquare = inSlotUV.x < slotWidth * 2;
					bool inLeftTile = inSlotUV.x < slotWidth;

					// Show only if within visible count and inside square region
					if (slotIndex < _VisibleSlotCount && inSquare)
					{
						//Low
						if (slotIndex == 0)//0
						{
							ColorTile encoded;
							float data = _PosX / 2.0;
							if (inLeftTile)
							{
								EncodeVideoSnorm(encoded, data, true);
								float4 guh = float4(encoded[0].r, encoded[0].g, encoded[0].b, 1.0);
								return LinearToGammaCustom(guh);
							}
							else
							{
								EncodeVideoSnorm(encoded, data, true);
								float4 guh = float4(encoded[1].r, encoded[1].g, encoded[1].b, 1.0);
								return LinearToGammaCustom(guh);
							}
						}
						if (slotIndex == 1)
						{
							ColorTile encoded;
							float data = _PosY / 2.0;
							if (inLeftTile)
							{
								EncodeVideoSnorm(encoded, data, true);
								float4 guh = float4(encoded[0].r, encoded[0].g, encoded[0].b, 1.0);
								return LinearToGammaCustom(guh);
							}
							else
							{
								EncodeVideoSnorm(encoded, data, true);
								float4 guh = float4(encoded[1].r, encoded[1].g, encoded[1].b, 1.0);
								return LinearToGammaCustom(guh);
							}
						}
						if (slotIndex == 2)
						{
							ColorTile encoded;
							float data = _PosZ / 2.0;
							if (inLeftTile)
							{
								EncodeVideoSnorm(encoded, data, true);
								float4 guh = float4(encoded[0].r, encoded[0].g, encoded[0].b, 1.0);
								return LinearToGammaCustom(guh);
							}
							else
							{
								EncodeVideoSnorm(encoded, data, true);
								float4 guh = float4(encoded[1].r, encoded[1].g, encoded[1].b, 1.0);
								return LinearToGammaCustom(guh);
							}
						}
						//High
						if (slotIndex == 3)
						{
							ColorTile encoded;
							float data = _PosX / 2.0;
							if (inLeftTile)
							{
								EncodeVideoSnorm(encoded, data, false);
								float4 guh = float4(encoded[0].r, encoded[0].g, encoded[0].b, 1.0);
								return LinearToGammaCustom(guh);
							}
							else
							{
								EncodeVideoSnorm(encoded, data, false);
								float4 guh = float4(encoded[1].r, encoded[1].g, encoded[1].b, 1.0);
								return LinearToGammaCustom(guh);
							}
						}
						if (slotIndex == 4)
						{
							ColorTile encoded;
							float data = _PosY / 2.0;
							if (inLeftTile)
							{
								EncodeVideoSnorm(encoded, data, false);
								float4 guh = float4(encoded[0].r, encoded[0].g, encoded[0].b, 1.0);
								return LinearToGammaCustom(guh);
							}
							else
							{
								EncodeVideoSnorm(encoded, data, false);
								float4 guh = float4(encoded[1].r, encoded[1].g, encoded[1].b, 1.0);
								return LinearToGammaCustom(guh);
							}
						}
						if (slotIndex == 5)
						{
							ColorTile encoded;
							float data = _PosZ / 2.0;
							if (inLeftTile)
							{
								EncodeVideoSnorm(encoded, data, false);
								float4 guh = float4(encoded[0].r, encoded[0].g, encoded[0].b, 1.0);
								return LinearToGammaCustom(guh);
							}
							else
							{
								EncodeVideoSnorm(encoded, data, false);
								float4 guh = float4(encoded[1].r, encoded[1].g, encoded[1].b, 1.0);
								return LinearToGammaCustom(guh);
							}
						}
						//scale???
						if (slotIndex == 6)
						{
							ColorTile encoded;
							float data = _QuaterionX;
							if (inLeftTile)
							{
								EncodeVideoSnorm(encoded, data, false);
								float4 guh = float4(encoded[0].r, encoded[0].g, encoded[0].b, 1.0);
								//float4 guh = float4(0.5, 0.5, 0.5, 1.0);
								return LinearToGammaCustom(guh);
							}
							else
							{
								EncodeVideoSnorm(encoded, data, false);
								float4 guh = float4(encoded[1].r, encoded[1].g, encoded[1].b, 1.0);
								//float4 guh = float4(0.5, 0.5, 0.5, 1.0);
								return LinearToGammaCustom(guh);
							}
						}
						if (slotIndex == 7)
						{
							ColorTile encoded;
							float data = _QuaterionY;
							if (inLeftTile)
							{
								EncodeVideoSnorm(encoded, data, false);
								float4 guh = float4(encoded[0].r, encoded[0].g, encoded[0].b, 1.0);
								//float4 guh = float4(1.0, 1.0, 0.5, 1.0);
								return LinearToGammaCustom(guh);
							}
							else
							{
								EncodeVideoSnorm(encoded, data, false);
								float4 guh = float4(encoded[1].r, encoded[1].g, encoded[1].b, 1.0);
								//float4 guh = float4(0.83984, 0.0, 0.0, 1.0);
								return LinearToGammaCustom(guh);
							}
						}
						if (slotIndex == 8)
						{
							ColorTile encoded;
							float data = _QuaterionZ;
							if (inLeftTile)
							{
								EncodeVideoSnorm(encoded, data, false);
								float4 guh = float4(encoded[0].r, encoded[0].g, encoded[0].b, 1.0);
								//float4 guh = float4(0.5, 0.5, 0.5, 1.0);
								return LinearToGammaCustom(guh);
							}
							else
							{
								EncodeVideoSnorm(encoded, data, false);
								float4 guh = float4(encoded[1].r, encoded[1].g, encoded[1].b, 1.0);
								//float4 guh = float4(0.5, 0.5, 0.5, 1.0);
								return LinearToGammaCustom(guh);

							}
						}
						if (slotIndex == 9)
						{
							ColorTile encoded;
							float data = _QuaterionW;
							if (inLeftTile)
							{
								EncodeVideoSnorm(encoded, data, false);
								float4 guh = float4(encoded[0].r, encoded[0].g, encoded[0].b, 1.0);
								//float4 guh = float4(0.5, 0.5, 0.5, 1.0);
								return LinearToGammaCustom(guh);
							}
							else
							{
								EncodeVideoSnorm(encoded, data, false);
								float4 guh = float4(encoded[1].r, encoded[1].g, encoded[1].b, 1.0);
								//float4 guh = float4(0.5, 0.5, 0.5, 1.0);
								return LinearToGammaCustom(guh);
							}
						}
						//if (slotIndex == 10)
						//{
						//	ColorTile encoded;
						//	float data = _RotZ.y;
						//	if (inLeftTile)
						//	{
						//		EncodeVideoSnorm(encoded, data, false);
						//		float4 guh = float4(encoded[0].r, encoded[0].g, encoded[0].b, 1.0);
						//		//float4 guh = float4(0.5, 0.5, 0.5, 1.0);
						//		return LinearToGammaCustom(guh);
						//	}
						//	else
						//	{
						//		EncodeVideoSnorm(encoded, data, false);
						//		float4 guh = float4(encoded[1].r, encoded[1].g, encoded[1].b, 1.0);
						//		//float4 guh = float4(0.5, 0.5, 0.5, 1.0);
						//		return LinearToGammaCustom(guh);
						//	}
						//}
						//if (slotIndex == 11)
						//{
						//	ColorTile encoded;
						//	float data = _RotZ.z;
						//	if (inLeftTile)
						//	{
						//		EncodeVideoSnorm(encoded, data, false);
						//		float4 guh = float4(encoded[0].r, encoded[0].g, encoded[0].b, 1.0);
						//		//float4 guh = float4(1.0, 1.0, 1.0, 1.0);
						//		return LinearToGammaCustom(guh);
						//	}
						//	else
						//	{
						//		EncodeVideoSnorm(encoded, data, false);
						//		float4 guh = float4(encoded[1].r, encoded[1].g, encoded[1].b, 1.0);
						//		//float4 guh = float4(1.0, 1.0, 1.0, 1.0);
						//		return LinearToGammaCustom(guh);
						//	}
						//}
						//swingtwist test
						if (slotIndex == 10)
						{
							ColorTile encoded;
							float data = _FOVSIZE;
							if (inLeftTile)
							{
								EncodeVideoSnorm(encoded, data, true);
								float4 guh = float4(encoded[0].r, encoded[0].g, encoded[0].b, 1.0);
								//float4 guh = float4(1.0, 1.0, 1.0, 1.0);
								return LinearToGammaCustom(guh);
							}
							else
							{
								EncodeVideoSnorm(encoded, data, true);
								float4 guh = float4(encoded[1].r, encoded[1].g, encoded[1].b, 1.0);
								//float4 guh = float4(1.0, 1.0, 1.0, 1.0);
								return LinearToGammaCustom(guh);
							}
						}
						if (slotIndex == 11)
						{
							ColorTile encoded;
							float data = _FOVSIZE;
							if (inLeftTile)
							{
								EncodeVideoSnorm(encoded, data, false);
								float4 guh = float4(encoded[0].r, encoded[0].g, encoded[0].b, 1.0);
								//float4 guh = float4(1.0, 1.0, 1.0, 1.0);
								return LinearToGammaCustom(guh);
							}
							else
							{
								EncodeVideoSnorm(encoded, data, false);
								float4 guh = float4(encoded[1].r, encoded[1].g, encoded[1].b, 1.0);
								//float4 guh = float4(1.0, 1.0, 1.0, 1.0);
								return LinearToGammaCustom(guh);
							}
						}
						//Near
						if (slotIndex == 12)
						{
							ColorTile encoded;
							float data = _NEAR;
							if (inLeftTile)
							{
								EncodeVideoSnorm(encoded, data, true);
								float4 guh = float4(encoded[0].r, encoded[0].g, encoded[0].b, 1.0);
								//float4 guh = float4(1.0, 1.0, 1.0, 1.0);
								return LinearToGammaCustom(guh);
							}
							else
							{
								EncodeVideoSnorm(encoded, data, true);
								float4 guh = float4(encoded[1].r, encoded[1].g, encoded[1].b, 1.0);
								//float4 guh = float4(1.0, 1.0, 1.0, 1.0);
								return LinearToGammaCustom(guh);
							}
						}
						if (slotIndex == 13)
						{
							ColorTile encoded;
							float data = _NEAR;
							if (inLeftTile)
							{
								EncodeVideoSnorm(encoded, data, false);
								float4 guh = float4(encoded[0].r, encoded[0].g, encoded[0].b, 1.0);
								//float4 guh = float4(1.0, 1.0, 1.0, 1.0);
								return LinearToGammaCustom(guh);
							}
							else
							{
								EncodeVideoSnorm(encoded, data, false);
								float4 guh = float4(encoded[1].r, encoded[1].g, encoded[1].b, 1.0);
								//float4 guh = float4(1.0, 1.0, 1.0, 1.0);
								return LinearToGammaCustom(guh);
							}
						}
						//Far
						if (slotIndex == 14)
						{
							ColorTile encoded;
							float data = _FAR;
							if (inLeftTile)
							{
								EncodeVideoSnorm(encoded, data, true);
								float4 guh = float4(encoded[0].r, encoded[0].g, encoded[0].b, 1.0);
								//float4 guh = float4(1.0, 1.0, 1.0, 1.0);
								return LinearToGammaCustom(guh);
							}
							else
							{
								EncodeVideoSnorm(encoded, data, true);
								float4 guh = float4(encoded[1].r, encoded[1].g, encoded[1].b, 1.0);
								//float4 guh = float4(1.0, 1.0, 1.0, 1.0);
								return LinearToGammaCustom(guh);
							}
						}
						if (slotIndex == 15)
						{
							ColorTile encoded;
							float data = _FAR;
							if (inLeftTile)
							{
								EncodeVideoSnorm(encoded, data, false);
								float4 guh = float4(encoded[0].r, encoded[0].g, encoded[0].b, 1.0);
								//float4 guh = float4(1.0, 1.0, 1.0, 1.0);
								return LinearToGammaCustom(guh);
							}
							else
							{
								EncodeVideoSnorm(encoded, data, false);
								float4 guh = float4(encoded[1].r, encoded[1].g, encoded[1].b, 1.0);
								//float4 guh = float4(1.0, 1.0, 1.0, 1.0);
								return LinearToGammaCustom(guh);
							}
						}
						//ortho
						if (slotIndex == 16)
						{
							ColorTile encoded;
							float data = _isOrtho;
							if (inLeftTile)
							{
								EncodeVideoSnorm(encoded, data, false);
								float4 guh = float4(encoded[0].r, encoded[0].g, encoded[0].b, 1.0);
								//float4 guh = float4(1.0, 1.0, 1.0, 1.0);
								return LinearToGammaCustom(guh);
							}
							else
							{
								EncodeVideoSnorm(encoded, data, false);
								float4 guh = float4(encoded[1].r, encoded[1].g, encoded[1].b, 1.0);
								//float4 guh = float4(1.0, 1.0, 1.0, 1.0);
								return LinearToGammaCustom(guh);
							}
						}





						return LinearToGammaCustom(float4(.5, 0.5, 0.5, 1));
					}
					return LinearToGammaCustom(float4(0.0, 0.0, 0.0, 0.0));
					/*float4 col = float4(0.0,0.0,0.0,1.0);

					return col;*/
				}
				ENDCG
			}
		}
}
