// Made with Amplify Shader Editor v1.9.9.3
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "Chaperone_VR"
{
	Properties
	{
		[HideInInspector] _AlphaCutoff("Alpha Cutoff ", Range(0, 1)) = 0.5
		[HideInInspector] _EmissionColor("Emission Color", Color) = (1,1,1,1)
		_BlueThreshold( "Blue Threshold", Float ) = 0.5
		_RedThreshold( "Red Threshold", Float ) = 0.3
		_FadeBand( "FadeBand", Float ) = 2
		_ShowDistance( "ShowDistance", Float ) = 2
		_CellSize( "CellSize", Float ) = 0
		_LineWidthMeters( "LineWidthMeters", Float ) = 0.03
		_TriSharp( "TriSharp", Float ) = 16


		//_TessPhongStrength( "Tess Phong Strength", Range( 0, 1 ) ) = 0.5
		//_TessValue( "Tess Max Tessellation", Range( 1, 32 ) ) = 16
		//_TessMin( "Tess Min Distance", Float ) = 10
		//_TessMax( "Tess Max Distance", Float ) = 25
		//_TessEdgeLength ( "Tess Edge length", Range( 2, 50 ) ) = 16
		//_TessMaxDisp( "Tess Max Displacement", Float ) = 25

		[HideInInspector] _QueueOffset("_QueueOffset", Float) = 0
        [HideInInspector] _QueueControl("_QueueControl", Float) = -1

        [HideInInspector][NoScaleOffset] unity_Lightmaps("unity_Lightmaps", 2DArray) = "" {}
        [HideInInspector][NoScaleOffset] unity_LightmapsInd("unity_LightmapsInd", 2DArray) = "" {}
        [HideInInspector][NoScaleOffset] unity_ShadowMasks("unity_ShadowMasks", 2DArray) = "" {}

		[HideInInspector][ToggleUI] _AddPrecomputedVelocity("Add Precomputed Velocity", Float) = 1
		[HideInInspector][ToggleOff] _ReceiveShadows("Receive Shadows", Float) = 0
	}

	SubShader
	{
		LOD 0

		

		Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="Transparent" "UniversalMaterialType"="Unlit" }

		Cull Off
		AlphaToMask Off

		

		HLSLINCLUDE
		#pragma target 4.5
		#pragma prefer_hlslcc gles
		#pragma only_renderers d3d11 glcore gles gles3 vulkan // ensure rendering platforms toggle list is visible

		#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
		#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Filtering.hlsl"

		#ifndef ASE_TESS_FUNCS
		#define ASE_TESS_FUNCS
		float4 FixedTess( float tessValue )
		{
			return tessValue;
		}

		float CalcDistanceTessFactor (float4 vertex, float minDist, float maxDist, float tess, float4x4 o2w, float3 cameraPos )
		{
			float3 wpos = mul(o2w,vertex).xyz;
			float dist = distance (wpos, cameraPos);
			float f = clamp(1.0 - (dist - minDist) / (maxDist - minDist), 0.01, 1.0) * tess;
			return f;
		}

		float4 CalcTriEdgeTessFactors (float3 triVertexFactors)
		{
			float4 tess;
			tess.x = 0.5 * (triVertexFactors.y + triVertexFactors.z);
			tess.y = 0.5 * (triVertexFactors.x + triVertexFactors.z);
			tess.z = 0.5 * (triVertexFactors.x + triVertexFactors.y);
			tess.w = (triVertexFactors.x + triVertexFactors.y + triVertexFactors.z) / 3.0f;
			return tess;
		}

		float CalcEdgeTessFactor (float3 wpos0, float3 wpos1, float edgeLen, float3 cameraPos, float4 scParams )
		{
			float dist = distance (0.5 * (wpos0+wpos1), cameraPos);
			float len = distance(wpos0, wpos1);
			float f = max(len * scParams.y / (edgeLen * dist), 1.0);
			return f;
		}

		float DistanceFromPlane (float3 pos, float4 plane)
		{
			float d = dot (float4(pos,1.0f), plane);
			return d;
		}

		bool WorldViewFrustumCull (float3 wpos0, float3 wpos1, float3 wpos2, float cullEps, float4 planes[6] )
		{
			float4 planeTest;
			planeTest.x = (( DistanceFromPlane(wpos0, planes[0]) > -cullEps) ? 1.0f : 0.0f ) +
							(( DistanceFromPlane(wpos1, planes[0]) > -cullEps) ? 1.0f : 0.0f ) +
							(( DistanceFromPlane(wpos2, planes[0]) > -cullEps) ? 1.0f : 0.0f );
			planeTest.y = (( DistanceFromPlane(wpos0, planes[1]) > -cullEps) ? 1.0f : 0.0f ) +
							(( DistanceFromPlane(wpos1, planes[1]) > -cullEps) ? 1.0f : 0.0f ) +
							(( DistanceFromPlane(wpos2, planes[1]) > -cullEps) ? 1.0f : 0.0f );
			planeTest.z = (( DistanceFromPlane(wpos0, planes[2]) > -cullEps) ? 1.0f : 0.0f ) +
							(( DistanceFromPlane(wpos1, planes[2]) > -cullEps) ? 1.0f : 0.0f ) +
							(( DistanceFromPlane(wpos2, planes[2]) > -cullEps) ? 1.0f : 0.0f );
			planeTest.w = (( DistanceFromPlane(wpos0, planes[3]) > -cullEps) ? 1.0f : 0.0f ) +
							(( DistanceFromPlane(wpos1, planes[3]) > -cullEps) ? 1.0f : 0.0f ) +
							(( DistanceFromPlane(wpos2, planes[3]) > -cullEps) ? 1.0f : 0.0f );
			return !all (planeTest);
		}

		float4 DistanceBasedTess( float4 v0, float4 v1, float4 v2, float tess, float minDist, float maxDist, float4x4 o2w, float3 cameraPos )
		{
			float3 f;
			f.x = CalcDistanceTessFactor (v0,minDist,maxDist,tess,o2w,cameraPos);
			f.y = CalcDistanceTessFactor (v1,minDist,maxDist,tess,o2w,cameraPos);
			f.z = CalcDistanceTessFactor (v2,minDist,maxDist,tess,o2w,cameraPos);

			return CalcTriEdgeTessFactors (f);
		}

		float4 EdgeLengthBasedTess( float4 v0, float4 v1, float4 v2, float edgeLength, float4x4 o2w, float3 cameraPos, float4 scParams )
		{
			float3 pos0 = mul(o2w,v0).xyz;
			float3 pos1 = mul(o2w,v1).xyz;
			float3 pos2 = mul(o2w,v2).xyz;
			float4 tess;
			tess.x = CalcEdgeTessFactor (pos1, pos2, edgeLength, cameraPos, scParams);
			tess.y = CalcEdgeTessFactor (pos2, pos0, edgeLength, cameraPos, scParams);
			tess.z = CalcEdgeTessFactor (pos0, pos1, edgeLength, cameraPos, scParams);
			tess.w = (tess.x + tess.y + tess.z) / 3.0f;
			return tess;
		}

		float4 EdgeLengthBasedTessCull( float4 v0, float4 v1, float4 v2, float edgeLength, float maxDisplacement, float4x4 o2w, float3 cameraPos, float4 scParams, float4 planes[6] )
		{
			float3 pos0 = mul(o2w,v0).xyz;
			float3 pos1 = mul(o2w,v1).xyz;
			float3 pos2 = mul(o2w,v2).xyz;
			float4 tess;

			if (WorldViewFrustumCull(pos0, pos1, pos2, maxDisplacement, planes))
			{
				tess = 0.0f;
			}
			else
			{
				tess.x = CalcEdgeTessFactor (pos1, pos2, edgeLength, cameraPos, scParams);
				tess.y = CalcEdgeTessFactor (pos2, pos0, edgeLength, cameraPos, scParams);
				tess.z = CalcEdgeTessFactor (pos0, pos1, edgeLength, cameraPos, scParams);
				tess.w = (tess.x + tess.y + tess.z) / 3.0f;
			}
			return tess;
		}
		#endif //ASE_TESS_FUNCS
		ENDHLSL

		
		Pass
		{
			
			Name "Forward"
			Tags { "LightMode"="UniversalForwardOnly" }

			Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
			ZWrite Off
			ZTest LEqual
			Offset 0 , 0
			ColorMask RGBA

			

			HLSLPROGRAM

			#pragma multi_compile_local _ALPHATEST_ON
			#pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
			#pragma multi_compile_instancing
			#pragma instancing_options renderinglayer
			#define _SURFACE_TYPE_TRANSPARENT 1
			#pragma multi_compile_local _RECEIVE_SHADOWS_OFF
			#define ASE_VERSION 19903
			#define ASE_SRP_VERSION 170004


			#pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3

			#pragma multi_compile_fragment _ DEBUG_DISPLAY

			#pragma vertex vert
			#pragma fragment frag

			#define SHADERPASS SHADERPASS_UNLIT

			#include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
			#include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
			#include_with_pragmas "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRenderingKeywords.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRendering.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Debug/Debugging3D.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceData.hlsl"

			#if defined(LOD_FADE_CROSSFADE)
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

			#define ASE_NEEDS_WORLD_NORMAL
			#define ASE_NEEDS_FRAG_WORLD_NORMAL
			#define ASE_NEEDS_WORLD_POSITION
			#define ASE_NEEDS_FRAG_WORLD_POSITION
			#define ASE_NEEDS_FRAG_SCREEN_POSITION
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl "


			#if defined(ASE_EARLY_Z_DEPTH_OPTIMIZE) && (SHADER_TARGET >= 45)
				#define ASE_SV_DEPTH SV_DepthLessEqual
				#define ASE_SV_POSITION_QUALIFIERS linear noperspective centroid
			#else
				#define ASE_SV_DEPTH SV_Depth
				#define ASE_SV_POSITION_QUALIFIERS
			#endif

			struct Attributes
			{
				float4 positionOS : POSITION;
				half3 normalOS : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct PackedVaryings
			{
				ASE_SV_POSITION_QUALIFIERS float4 positionCS : SV_POSITION;
				float4 positionWSAndFogFactor : TEXCOORD0;
				half3 normalWS : TEXCOORD1;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
			float _TriSharp;
			float _LineWidthMeters;
			float _CellSize;
			float _RedThreshold;
			float _BlueThreshold;
			float _ShowDistance;
			float _FadeBand;
			#ifdef ASE_TESSELLATION
				float _TessPhongStrength;
				float _TessValue;
				float _TessMin;
				float _TessMax;
				float _TessEdgeLength;
				float _TessMaxDisp;
			#endif
			CBUFFER_END

			

			float3 ASE_GetCenterEyeWS(  )
			{
				#if defined(UNITY_STEREO_INSTANCING_ENABLED) || defined(UNITY_STEREO_MULTIVIEW_ENABLED)
				    return 0.5 * (unity_StereoWorldSpaceCameraPos[0] + unity_StereoWorldSpaceCameraPos[1]);
				#else
				    return GetCameraPositionWS();
				#endif
			}
			

			PackedVaryings VertexFunction( Attributes input  )
			{
				PackedVaryings output = (PackedVaryings)0;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

				

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = input.positionOS.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif

				float3 vertexValue = defaultVertexValue;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					input.positionOS.xyz = vertexValue;
				#else
					input.positionOS.xyz += vertexValue;
				#endif

				input.normalOS = input.normalOS;

				VertexPositionInputs vertexInput = GetVertexPositionInputs( input.positionOS.xyz );
				VertexNormalInputs normalInput = GetVertexNormalInputs( input.normalOS );

				float fogFactor = 0;
				#if defined(ASE_FOG) && !defined(_FOG_FRAGMENT)
					fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
				#endif

				output.positionCS = vertexInput.positionCS;
				output.positionWSAndFogFactor = float4( vertexInput.positionWS, fogFactor );
				output.normalWS = normalInput.normalWS;
				return output;
			}

			#if defined(ASE_TESSELLATION)
			struct VertexControl
			{
				float4 positionOS : INTERNALTESSPOS;
				half3 normalOS : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct TessellationFactors
			{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

			VertexControl vert ( Attributes input )
			{
				VertexControl output;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				output.positionOS = input.positionOS;
				output.normalOS = input.normalOS;
				
				return output;
			}

			TessellationFactors TessellationFunction (InputPatch<VertexControl,3> input)
			{
				TessellationFactors output;
				float4 tf = 1;
				float tessValue = _TessValue; float tessMin = _TessMin; float tessMax = _TessMax;
				float edgeLength = _TessEdgeLength; float tessMaxDisp = _TessMaxDisp;
				#if defined(ASE_FIXED_TESSELLATION)
				tf = FixedTess( tessValue );
				#elif defined(ASE_DISTANCE_TESSELLATION)
				tf = DistanceBasedTess(input[0].positionOS, input[1].positionOS, input[2].positionOS, tessValue, tessMin, tessMax, GetObjectToWorldMatrix(), _WorldSpaceCameraPos );
				#elif defined(ASE_LENGTH_TESSELLATION)
				tf = EdgeLengthBasedTess(input[0].positionOS, input[1].positionOS, input[2].positionOS, edgeLength, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams );
				#elif defined(ASE_LENGTH_CULL_TESSELLATION)
				tf = EdgeLengthBasedTessCull(input[0].positionOS, input[1].positionOS, input[2].positionOS, edgeLength, tessMaxDisp, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams, unity_CameraWorldClipPlanes );
				#endif
				output.edge[0] = tf.x; output.edge[1] = tf.y; output.edge[2] = tf.z; output.inside = tf.w;
				return output;
			}

			[domain("tri")]
			[partitioning("fractional_odd")]
			[outputtopology("triangle_cw")]
			[patchconstantfunc("TessellationFunction")]
			[outputcontrolpoints(3)]
			VertexControl HullFunction(InputPatch<VertexControl, 3> patch, uint id : SV_OutputControlPointID)
			{
				return patch[id];
			}

			[domain("tri")]
			PackedVaryings DomainFunction(TessellationFactors factors, OutputPatch<VertexControl, 3> patch, float3 bary : SV_DomainLocation)
			{
				Attributes output = (Attributes) 0;
				output.positionOS = patch[0].positionOS * bary.x + patch[1].positionOS * bary.y + patch[2].positionOS * bary.z;
				output.normalOS = patch[0].normalOS * bary.x + patch[1].normalOS * bary.y + patch[2].normalOS * bary.z;
				
				#if defined(ASE_PHONG_TESSELLATION)
				float3 pp[3];
				for (int i = 0; i < 3; ++i)
					pp[i] = output.positionOS.xyz - patch[i].normalOS * (dot(output.positionOS.xyz, patch[i].normalOS) - dot(patch[i].positionOS.xyz, patch[i].normalOS));
				float phongStrength = _TessPhongStrength;
				output.positionOS.xyz = phongStrength * (pp[0]*bary.x + pp[1]*bary.y + pp[2]*bary.z) + (1.0f-phongStrength) * output.positionOS.xyz;
				#endif
				UNITY_TRANSFER_INSTANCE_ID(patch[0], output);
				return VertexFunction(output);
			}
			#else
			PackedVaryings vert ( Attributes input )
			{
				return VertexFunction( input );
			}
			#endif

			half4 frag ( PackedVaryings input
						#if defined( ASE_DEPTH_WRITE_ON )
						,out float outputDepth : ASE_SV_DEPTH
						#endif
						#ifdef _WRITE_RENDERING_LAYERS
						, out float4 outRenderingLayers : SV_Target1
						#endif
						 ) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

				#if defined( _SURFACE_TYPE_TRANSPARENT )
					const bool isTransparent = true;
				#else
					const bool isTransparent = false;
				#endif

				#if defined(LOD_FADE_CROSSFADE)
					LODFadeCrossFade( input.positionCS );
				#endif

				#if defined(MAIN_LIGHT_CALCULATE_SHADOWS)
					float4 shadowCoord = TransformWorldToShadowCoord( input.positionWSAndFogFactor.xyz );
				#else
					float4 shadowCoord = float4(0, 0, 0, 0);
				#endif

				float3 PositionWS = input.positionWSAndFogFactor.xyz;
				float3 PositionRWS = GetCameraRelativePositionWS( PositionWS );
				half3 ViewDirWS = GetWorldSpaceNormalizeViewDir( PositionWS );
				float4 ShadowCoord = shadowCoord;
				float4 ScreenPosNorm = float4( GetNormalizedScreenSpaceUV( input.positionCS ), input.positionCS.zw );
				float4 ClipPos = ComputeClipSpacePosition( ScreenPosNorm.xy, input.positionCS.z ) * input.positionCS.w;
				float4 ScreenPos = ComputeScreenPos( ClipPos );
				half3 NormalWS = normalize( input.normalWS );

				float3 normalizeResult227 = normalize( NormalWS );
				float3 temp_cast_0 = (_TriSharp).xxx;
				float3 temp_output_228_0 = pow( abs( normalizeResult227 ) , temp_cast_0 );
				float dotResult233 = dot( temp_output_228_0 , float3( 1,1,1 ) );
				float3 break240 = ( temp_output_228_0 / max( dotResult233 , 0.0001 ) );
				float temp_output_191_0 = max( _CellSize , 0.001 );
				float temp_output_182_0 = ( _LineWidthMeters / temp_output_191_0 );
				float2 temp_output_174_0 = ( (PositionWS).yz / temp_output_191_0 );
				float2 break178 = fwidth( temp_output_174_0 );
				float temp_output_183_0 = ( max( break178.x , break178.y ) * 0.5 );
				float2 temp_output_175_0 = frac( temp_output_174_0 );
				float2 break184 = min( temp_output_175_0 , ( 1.0 - temp_output_175_0 ) );
				float smoothstepResult186 = smoothstep( ( temp_output_182_0 - temp_output_183_0 ) , ( temp_output_182_0 + temp_output_183_0 ) , min( break184.x , break184.y ));
				float LINE_YZ246 = smoothstepResult186;
				float temp_output_198_0 = max( _CellSize , 0.001 );
				float temp_output_214_0 = ( _LineWidthMeters / temp_output_198_0 );
				float2 temp_output_202_0 = ( (PositionWS).xz / temp_output_198_0 );
				float2 break209 = fwidth( temp_output_202_0 );
				float temp_output_215_0 = ( max( break209.x , break209.y ) * 0.5 );
				float2 temp_output_204_0 = frac( temp_output_202_0 );
				float2 break216 = min( temp_output_204_0 , ( 1.0 - temp_output_204_0 ) );
				float smoothstepResult220 = smoothstep( ( temp_output_214_0 - temp_output_215_0 ) , ( temp_output_214_0 + temp_output_215_0 ) , min( break216.x , break216.y ));
				float LINE_XZ244 = smoothstepResult220;
				float temp_output_137_0 = max( _CellSize , 0.001 );
				float temp_output_146_0 = ( _LineWidthMeters / temp_output_137_0 );
				float2 temp_output_121_0 = ( (PositionWS).xy / temp_output_137_0 );
				float2 break151 = fwidth( temp_output_121_0 );
				float temp_output_153_0 = ( max( break151.x , break151.y ) * 0.5 );
				float2 temp_output_125_0 = frac( temp_output_121_0 );
				float2 break130 = min( temp_output_125_0 , ( 1.0 - temp_output_125_0 ) );
				float smoothstepResult147 = smoothstep( ( temp_output_146_0 - temp_output_153_0 ) , ( temp_output_146_0 + temp_output_153_0 ) , min( break130.x , break130.y ));
				float LINE_XY248 = smoothstepResult147;
				float temp_output_258_0 = ( 1.0 - ( ( ( break240.x * LINE_YZ246 ) + ( break240.y * LINE_XZ244 ) ) + ( break240.z * LINE_XY248 ) ) );
				float4 color29 = IsGammaSpace() ? float4( 1, 0, 0, 1 ) : float4( 1, 0, 0, 1 );
				float4 color30 = IsGammaSpace() ? float4( 0, 0.764706, 1, 1 ) : float4( 0, 0.5457247, 1, 1 );
				float3 temp_output_39_0 = float3( 0,0,0 );
				float clampResult31 = clamp( ( ( distance( float4( temp_output_39_0 , 0.0 ) , ScreenPos ) - _RedThreshold ) / ( _BlueThreshold - _RedThreshold ) ) , 0.0 , 1.0 );
				float4 lerpResult28 = lerp( color29 , color30 , clampResult31);
				
				float3 localASE_GetCenterEyeWS269 = ASE_GetCenterEyeWS();
				float3 worldToObj76 = mul( GetWorldToObjectMatrix(), float4( localASE_GetCenterEyeWS269, 1 ) ).xyz;
				float3 ase_objectScale = float3( length( GetObjectToWorldMatrix()[ 0 ].xyz ), length( GetObjectToWorldMatrix()[ 1 ].xyz ), length( GetObjectToWorldMatrix()[ 2 ].xyz ) );
				float3 temp_output_124_0 = ( ( abs( ( worldToObj76 - float3( 0, 0, 0 ) ) ) - float3( 0.5, 0.5, 0.5 ) ) * ase_objectScale );
				float3 break90 = temp_output_124_0;
				float clampResult110 = clamp( ( ( abs( ( min( max( max( break90.x , break90.y ) , break90.z ) , 0.0 ) + length( max( temp_output_124_0 , float3( 0,0,0 ) ) ) ) ) - _ShowDistance ) / max( _FadeBand , 0.0001 ) ) , 0.0 , 1.0 );
				float smoothstepResult111 = smoothstep( 0.0 , 1.0 , clampResult110);
				
				float3 BakedAlbedo = 0;
				float3 BakedEmission = 0;
				float3 Color = ( temp_output_258_0 * lerpResult28 ).rgb;
				float Alpha = ( temp_output_258_0 * ( 1.0 - smoothstepResult111 ) );
				float AlphaClipThreshold = 0.5;
				float AlphaClipThresholdShadow = 0.5;

				#if defined( ASE_DEPTH_WRITE_ON )
					float DeviceDepth = input.positionCS.z;
				#endif

				#if defined( _ALPHATEST_ON )
					AlphaDiscard( Alpha, AlphaClipThreshold );
				#endif

				#if defined(MAIN_LIGHT_CALCULATE_SHADOWS) && defined(ASE_CHANGES_WORLD_POS)
					ShadowCoord = TransformWorldToShadowCoord( PositionWS );
				#endif

				InputData inputData = (InputData)0;
				inputData.positionWS = PositionWS;
				inputData.positionCS = float4( input.positionCS.xy, ClipPos.zw / ClipPos.w );
				inputData.normalizedScreenSpaceUV = ScreenPosNorm.xy;
				inputData.normalWS = NormalWS;
				inputData.viewDirectionWS = ViewDirWS;

				#if defined(_SCREEN_SPACE_OCCLUSION) && !defined(_SURFACE_TYPE_TRANSPARENT)
					float2 normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
					AmbientOcclusionFactor aoFactor = GetScreenSpaceAmbientOcclusion(normalizedScreenSpaceUV);
					Color.rgb *= aoFactor.directAmbientOcclusion;
				#endif

				#ifdef ASE_FOG
					inputData.fogCoord = InitializeInputDataFog(float4(inputData.positionWS, 1.0), input.positionWSAndFogFactor.w);
				#endif

				#if defined(_DBUFFER)
					ApplyDecalToBaseColor(input.positionCS, Color);
				#endif

				#ifdef ASE_FOG
					#ifdef TERRAIN_SPLAT_ADDPASS
						Color.rgb = MixFogColor(Color.rgb, half3(0,0,0), inputData.fogCoord);
					#else
						Color.rgb = MixFog(Color.rgb, inputData.fogCoord);
					#endif
				#endif

				#if defined( ASE_DEPTH_WRITE_ON )
					outputDepth = DeviceDepth;
				#endif

				#ifdef _WRITE_RENDERING_LAYERS
					uint renderingLayers = GetMeshRenderingLayer();
					outRenderingLayers = float4( EncodeMeshRenderingLayer( renderingLayers ), 0, 0, 0 );
				#endif

				return half4( Color, OutputAlpha( Alpha, isTransparent ) );
			}
			ENDHLSL
		}

		
		Pass
		{
			
			Name "DepthOnly"
			Tags { "LightMode"="DepthOnly" }

			ZWrite On
			ColorMask R
			AlphaToMask Off

			HLSLPROGRAM

			#pragma multi_compile_local _ALPHATEST_ON
			#pragma multi_compile_instancing
			#define _SURFACE_TYPE_TRANSPARENT 1
			#define ASE_VERSION 19903
			#define ASE_SRP_VERSION 170004


			#pragma vertex vert
			#pragma fragment frag

			#include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"

			#if defined(LOD_FADE_CROSSFADE)
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

			#define ASE_NEEDS_VERT_NORMAL
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl "


			#if defined(ASE_EARLY_Z_DEPTH_OPTIMIZE) && (SHADER_TARGET >= 45)
				#define ASE_SV_DEPTH SV_DepthLessEqual
				#define ASE_SV_POSITION_QUALIFIERS linear noperspective centroid
			#else
				#define ASE_SV_DEPTH SV_Depth
				#define ASE_SV_POSITION_QUALIFIERS
			#endif

			struct Attributes
			{
				float4 positionOS : POSITION;
				half3 normalOS : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct PackedVaryings
			{
				ASE_SV_POSITION_QUALIFIERS float4 positionCS : SV_POSITION;
				float4 ase_texcoord : TEXCOORD0;
				float4 ase_texcoord1 : TEXCOORD1;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
			float _TriSharp;
			float _LineWidthMeters;
			float _CellSize;
			float _RedThreshold;
			float _BlueThreshold;
			float _ShowDistance;
			float _FadeBand;
			#ifdef ASE_TESSELLATION
				float _TessPhongStrength;
				float _TessValue;
				float _TessMin;
				float _TessMax;
				float _TessEdgeLength;
				float _TessMaxDisp;
			#endif
			CBUFFER_END

			

			float3 ASE_GetCenterEyeWS(  )
			{
				#if defined(UNITY_STEREO_INSTANCING_ENABLED) || defined(UNITY_STEREO_MULTIVIEW_ENABLED)
				    return 0.5 * (unity_StereoWorldSpaceCameraPos[0] + unity_StereoWorldSpaceCameraPos[1]);
				#else
				    return GetCameraPositionWS();
				#endif
			}
			

			PackedVaryings VertexFunction( Attributes input  )
			{
				PackedVaryings output = (PackedVaryings)0;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

				float3 ase_normalWS = TransformObjectToWorldNormal( input.normalOS );
				output.ase_texcoord.xyz = ase_normalWS;
				float3 ase_positionWS = TransformObjectToWorld( ( input.positionOS ).xyz );
				output.ase_texcoord1.xyz = ase_positionWS;
				
				
				//setting value to unused interpolator channels and avoid initialization warnings
				output.ase_texcoord.w = 0;
				output.ase_texcoord1.w = 0;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = input.positionOS.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif

				float3 vertexValue = defaultVertexValue;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					input.positionOS.xyz = vertexValue;
				#else
					input.positionOS.xyz += vertexValue;
				#endif

				VertexPositionInputs vertexInput = GetVertexPositionInputs( input.positionOS.xyz );

				output.positionCS = vertexInput.positionCS;
				return output;
			}

			#if defined(ASE_TESSELLATION)
			struct VertexControl
			{
				float4 positionOS : INTERNALTESSPOS;
				half3 normalOS : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct TessellationFactors
			{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

			VertexControl vert ( Attributes input )
			{
				VertexControl output;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				output.positionOS = input.positionOS;
				output.normalOS = input.normalOS;
				
				return output;
			}

			TessellationFactors TessellationFunction (InputPatch<VertexControl,3> input)
			{
				TessellationFactors output;
				float4 tf = 1;
				float tessValue = _TessValue; float tessMin = _TessMin; float tessMax = _TessMax;
				float edgeLength = _TessEdgeLength; float tessMaxDisp = _TessMaxDisp;
				#if defined(ASE_FIXED_TESSELLATION)
				tf = FixedTess( tessValue );
				#elif defined(ASE_DISTANCE_TESSELLATION)
				tf = DistanceBasedTess(input[0].positionOS, input[1].positionOS, input[2].positionOS, tessValue, tessMin, tessMax, GetObjectToWorldMatrix(), _WorldSpaceCameraPos );
				#elif defined(ASE_LENGTH_TESSELLATION)
				tf = EdgeLengthBasedTess(input[0].positionOS, input[1].positionOS, input[2].positionOS, edgeLength, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams );
				#elif defined(ASE_LENGTH_CULL_TESSELLATION)
				tf = EdgeLengthBasedTessCull(input[0].positionOS, input[1].positionOS, input[2].positionOS, edgeLength, tessMaxDisp, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams, unity_CameraWorldClipPlanes );
				#endif
				output.edge[0] = tf.x; output.edge[1] = tf.y; output.edge[2] = tf.z; output.inside = tf.w;
				return output;
			}

			[domain("tri")]
			[partitioning("fractional_odd")]
			[outputtopology("triangle_cw")]
			[patchconstantfunc("TessellationFunction")]
			[outputcontrolpoints(3)]
			VertexControl HullFunction(InputPatch<VertexControl, 3> patch, uint id : SV_OutputControlPointID)
			{
				return patch[id];
			}

			[domain("tri")]
			PackedVaryings DomainFunction(TessellationFactors factors, OutputPatch<VertexControl, 3> patch, float3 bary : SV_DomainLocation)
			{
				Attributes output = (Attributes) 0;
				output.positionOS = patch[0].positionOS * bary.x + patch[1].positionOS * bary.y + patch[2].positionOS * bary.z;
				output.normalOS = patch[0].normalOS * bary.x + patch[1].normalOS * bary.y + patch[2].normalOS * bary.z;
				
				#if defined(ASE_PHONG_TESSELLATION)
				float3 pp[3];
				for (int i = 0; i < 3; ++i)
					pp[i] = output.positionOS.xyz - patch[i].normalOS * (dot(output.positionOS.xyz, patch[i].normalOS) - dot(patch[i].positionOS.xyz, patch[i].normalOS));
				float phongStrength = _TessPhongStrength;
				output.positionOS.xyz = phongStrength * (pp[0]*bary.x + pp[1]*bary.y + pp[2]*bary.z) + (1.0f-phongStrength) * output.positionOS.xyz;
				#endif
				UNITY_TRANSFER_INSTANCE_ID(patch[0], output);
				return VertexFunction(output);
			}
			#else
			PackedVaryings vert ( Attributes input )
			{
				return VertexFunction( input );
			}
			#endif

			half4 frag(PackedVaryings input
						#if defined( ASE_DEPTH_WRITE_ON )
						,out float outputDepth : ASE_SV_DEPTH
						#endif
						 ) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX( input );

				float4 ScreenPosNorm = float4( GetNormalizedScreenSpaceUV( input.positionCS ), input.positionCS.zw );
				float4 ClipPos = ComputeClipSpacePosition( ScreenPosNorm.xy, input.positionCS.z ) * input.positionCS.w;
				float4 ScreenPos = ComputeScreenPos( ClipPos );

				float3 ase_normalWS = input.ase_texcoord.xyz;
				float3 normalizeResult227 = normalize( ase_normalWS );
				float3 temp_cast_0 = (_TriSharp).xxx;
				float3 temp_output_228_0 = pow( abs( normalizeResult227 ) , temp_cast_0 );
				float dotResult233 = dot( temp_output_228_0 , float3( 1,1,1 ) );
				float3 break240 = ( temp_output_228_0 / max( dotResult233 , 0.0001 ) );
				float temp_output_191_0 = max( _CellSize , 0.001 );
				float temp_output_182_0 = ( _LineWidthMeters / temp_output_191_0 );
				float3 ase_positionWS = input.ase_texcoord1.xyz;
				float2 temp_output_174_0 = ( (ase_positionWS).yz / temp_output_191_0 );
				float2 break178 = fwidth( temp_output_174_0 );
				float temp_output_183_0 = ( max( break178.x , break178.y ) * 0.5 );
				float2 temp_output_175_0 = frac( temp_output_174_0 );
				float2 break184 = min( temp_output_175_0 , ( 1.0 - temp_output_175_0 ) );
				float smoothstepResult186 = smoothstep( ( temp_output_182_0 - temp_output_183_0 ) , ( temp_output_182_0 + temp_output_183_0 ) , min( break184.x , break184.y ));
				float LINE_YZ246 = smoothstepResult186;
				float temp_output_198_0 = max( _CellSize , 0.001 );
				float temp_output_214_0 = ( _LineWidthMeters / temp_output_198_0 );
				float2 temp_output_202_0 = ( (ase_positionWS).xz / temp_output_198_0 );
				float2 break209 = fwidth( temp_output_202_0 );
				float temp_output_215_0 = ( max( break209.x , break209.y ) * 0.5 );
				float2 temp_output_204_0 = frac( temp_output_202_0 );
				float2 break216 = min( temp_output_204_0 , ( 1.0 - temp_output_204_0 ) );
				float smoothstepResult220 = smoothstep( ( temp_output_214_0 - temp_output_215_0 ) , ( temp_output_214_0 + temp_output_215_0 ) , min( break216.x , break216.y ));
				float LINE_XZ244 = smoothstepResult220;
				float temp_output_137_0 = max( _CellSize , 0.001 );
				float temp_output_146_0 = ( _LineWidthMeters / temp_output_137_0 );
				float2 temp_output_121_0 = ( (ase_positionWS).xy / temp_output_137_0 );
				float2 break151 = fwidth( temp_output_121_0 );
				float temp_output_153_0 = ( max( break151.x , break151.y ) * 0.5 );
				float2 temp_output_125_0 = frac( temp_output_121_0 );
				float2 break130 = min( temp_output_125_0 , ( 1.0 - temp_output_125_0 ) );
				float smoothstepResult147 = smoothstep( ( temp_output_146_0 - temp_output_153_0 ) , ( temp_output_146_0 + temp_output_153_0 ) , min( break130.x , break130.y ));
				float LINE_XY248 = smoothstepResult147;
				float temp_output_258_0 = ( 1.0 - ( ( ( break240.x * LINE_YZ246 ) + ( break240.y * LINE_XZ244 ) ) + ( break240.z * LINE_XY248 ) ) );
				float3 localASE_GetCenterEyeWS269 = ASE_GetCenterEyeWS();
				float3 worldToObj76 = mul( GetWorldToObjectMatrix(), float4( localASE_GetCenterEyeWS269, 1 ) ).xyz;
				float3 ase_objectScale = float3( length( GetObjectToWorldMatrix()[ 0 ].xyz ), length( GetObjectToWorldMatrix()[ 1 ].xyz ), length( GetObjectToWorldMatrix()[ 2 ].xyz ) );
				float3 temp_output_124_0 = ( ( abs( ( worldToObj76 - float3( 0, 0, 0 ) ) ) - float3( 0.5, 0.5, 0.5 ) ) * ase_objectScale );
				float3 break90 = temp_output_124_0;
				float clampResult110 = clamp( ( ( abs( ( min( max( max( break90.x , break90.y ) , break90.z ) , 0.0 ) + length( max( temp_output_124_0 , float3( 0,0,0 ) ) ) ) ) - _ShowDistance ) / max( _FadeBand , 0.0001 ) ) , 0.0 , 1.0 );
				float smoothstepResult111 = smoothstep( 0.0 , 1.0 , clampResult110);
				

				float Alpha = ( temp_output_258_0 * ( 1.0 - smoothstepResult111 ) );
				float AlphaClipThreshold = 0.5;

				#if defined( ASE_DEPTH_WRITE_ON )
					float DeviceDepth = input.positionCS.z;
				#endif

				#if defined( _ALPHATEST_ON )
					AlphaDiscard( Alpha, AlphaClipThreshold );
				#endif

				#if defined(LOD_FADE_CROSSFADE)
					LODFadeCrossFade( input.positionCS );
				#endif

				#if defined( ASE_DEPTH_WRITE_ON )
					outputDepth = DeviceDepth;
				#endif

				return 0;
			}
			ENDHLSL
		}

		
		Pass
		{
			
			Name "Meta"
			Tags { "LightMode"="Meta" }

			Cull Off

			HLSLPROGRAM

			#pragma multi_compile_local _ALPHATEST_ON
			#define _SURFACE_TYPE_TRANSPARENT 1
			#define ASE_VERSION 19903
			#define ASE_SRP_VERSION 170004


			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/MetaInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"

			#define ASE_NEEDS_VERT_NORMAL
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl "


			struct Attributes
			{
				float4 positionOS : POSITION;
				half3 normalOS : NORMAL;
				float4 texcoord1 : TEXCOORD1;
				float4 texcoord2 : TEXCOORD2;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct PackedVaryings
			{
				float4 positionCS : SV_POSITION;
				float4 ase_texcoord : TEXCOORD0;
				float4 ase_texcoord1 : TEXCOORD1;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
			float _TriSharp;
			float _LineWidthMeters;
			float _CellSize;
			float _RedThreshold;
			float _BlueThreshold;
			float _ShowDistance;
			float _FadeBand;
			#ifdef ASE_TRANSMISSION
				float _TransmissionShadow;
			#endif
			#ifdef ASE_TRANSLUCENCY
				float _TransStrength;
				float _TransNormal;
				float _TransScattering;
				float _TransDirect;
				float _TransAmbient;
				float _TransShadow;
			#endif
			#ifdef ASE_TESSELLATION
				float _TessPhongStrength;
				float _TessValue;
				float _TessMin;
				float _TessMax;
				float _TessEdgeLength;
				float _TessMaxDisp;
			#endif
			CBUFFER_END

			#ifdef SCENEPICKINGPASS
				float4 _SelectionID;
			#endif

			#ifdef SCENESELECTIONPASS
				int _ObjectId;
				int _PassValue;
			#endif

			

			float3 ASE_GetCenterEyeWS(  )
			{
				#if defined(UNITY_STEREO_INSTANCING_ENABLED) || defined(UNITY_STEREO_MULTIVIEW_ENABLED)
				    return 0.5 * (unity_StereoWorldSpaceCameraPos[0] + unity_StereoWorldSpaceCameraPos[1]);
				#else
				    return GetCameraPositionWS();
				#endif
			}
			

			PackedVaryings VertexFunction( Attributes input  )
			{
				PackedVaryings output = (PackedVaryings)0;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

				float3 ase_normalWS = TransformObjectToWorldNormal( input.normalOS );
				output.ase_texcoord.xyz = ase_normalWS;
				float3 ase_positionWS = TransformObjectToWorld( ( input.positionOS ).xyz );
				output.ase_texcoord1.xyz = ase_positionWS;
				
				
				//setting value to unused interpolator channels and avoid initialization warnings
				output.ase_texcoord.w = 0;
				output.ase_texcoord1.w = 0;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = input.positionOS.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif

				float3 vertexValue = defaultVertexValue;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					input.positionOS.xyz = vertexValue;
				#else
					input.positionOS.xyz += vertexValue;
				#endif

				output.positionCS = MetaVertexPosition( input.positionOS, input.texcoord1.xy, input.texcoord1.xy, unity_LightmapST, unity_DynamicLightmapST );
				return output;
			}

			#if defined(ASE_TESSELLATION)
			struct VertexControl
			{
				float4 positionOS : INTERNALTESSPOS;
				half3 normalOS : NORMAL;
				float4 texcoord1 : TEXCOORD1;
				float4 texcoord2 : TEXCOORD2;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct TessellationFactors
			{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

			VertexControl vert ( Attributes input )
			{
				VertexControl output;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				output.positionOS = input.positionOS;
				output.normalOS = input.normalOS;
				output.texcoord1 = input.texcoord1;
				output.texcoord2 = input.texcoord2;
				
				return output;
			}

			TessellationFactors TessellationFunction (InputPatch<VertexControl,3> input)
			{
				TessellationFactors output;
				float4 tf = 1;
				float tessValue = _TessValue; float tessMin = _TessMin; float tessMax = _TessMax;
				float edgeLength = _TessEdgeLength; float tessMaxDisp = _TessMaxDisp;
				#if defined(ASE_FIXED_TESSELLATION)
				tf = FixedTess( tessValue );
				#elif defined(ASE_DISTANCE_TESSELLATION)
				tf = DistanceBasedTess(input[0].positionOS, input[1].positionOS, input[2].positionOS, tessValue, tessMin, tessMax, GetObjectToWorldMatrix(), _WorldSpaceCameraPos );
				#elif defined(ASE_LENGTH_TESSELLATION)
				tf = EdgeLengthBasedTess(input[0].positionOS, input[1].positionOS, input[2].positionOS, edgeLength, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams );
				#elif defined(ASE_LENGTH_CULL_TESSELLATION)
				tf = EdgeLengthBasedTessCull(input[0].positionOS, input[1].positionOS, input[2].positionOS, edgeLength, tessMaxDisp, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams, unity_CameraWorldClipPlanes );
				#endif
				output.edge[0] = tf.x; output.edge[1] = tf.y; output.edge[2] = tf.z; output.inside = tf.w;
				return output;
			}

			[domain("tri")]
			[partitioning("fractional_odd")]
			[outputtopology("triangle_cw")]
			[patchconstantfunc("TessellationFunction")]
			[outputcontrolpoints(3)]
			VertexControl HullFunction(InputPatch<VertexControl, 3> patch, uint id : SV_OutputControlPointID)
			{
				return patch[id];
			}

			[domain("tri")]
			PackedVaryings DomainFunction(TessellationFactors factors, OutputPatch<VertexControl, 3> patch, float3 bary : SV_DomainLocation)
			{
				Attributes output = (Attributes) 0;
				output.positionOS = patch[0].positionOS * bary.x + patch[1].positionOS * bary.y + patch[2].positionOS * bary.z;
				output.normalOS = patch[0].normalOS * bary.x + patch[1].normalOS * bary.y + patch[2].normalOS * bary.z;
				output.texcoord1 = patch[0].texcoord1 * bary.x + patch[1].texcoord1 * bary.y + patch[2].texcoord1 * bary.z;
				output.texcoord2 = patch[0].texcoord2 * bary.x + patch[1].texcoord2 * bary.y + patch[2].texcoord2 * bary.z;
				
				#if defined(ASE_PHONG_TESSELLATION)
				float3 pp[3];
				for (int i = 0; i < 3; ++i)
					pp[i] = output.positionOS.xyz - patch[i].normalOS * (dot(output.positionOS.xyz, patch[i].normalOS) - dot(patch[i].positionOS.xyz, patch[i].normalOS));
				float phongStrength = _TessPhongStrength;
				output.positionOS.xyz = phongStrength * (pp[0]*bary.x + pp[1]*bary.y + pp[2]*bary.z) + (1.0f-phongStrength) * output.positionOS.xyz;
				#endif
				UNITY_TRANSFER_INSTANCE_ID(patch[0], output);
				return VertexFunction(output);
			}
			#else
			PackedVaryings vert ( Attributes input )
			{
				return VertexFunction( input );
			}
			#endif

			half4 frag(PackedVaryings input  ) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX( input );

				float3 ase_normalWS = input.ase_texcoord.xyz;
				float3 normalizeResult227 = normalize( ase_normalWS );
				float3 temp_cast_0 = (_TriSharp).xxx;
				float3 temp_output_228_0 = pow( abs( normalizeResult227 ) , temp_cast_0 );
				float dotResult233 = dot( temp_output_228_0 , float3( 1,1,1 ) );
				float3 break240 = ( temp_output_228_0 / max( dotResult233 , 0.0001 ) );
				float temp_output_191_0 = max( _CellSize , 0.001 );
				float temp_output_182_0 = ( _LineWidthMeters / temp_output_191_0 );
				float3 ase_positionWS = input.ase_texcoord1.xyz;
				float2 temp_output_174_0 = ( (ase_positionWS).yz / temp_output_191_0 );
				float2 break178 = fwidth( temp_output_174_0 );
				float temp_output_183_0 = ( max( break178.x , break178.y ) * 0.5 );
				float2 temp_output_175_0 = frac( temp_output_174_0 );
				float2 break184 = min( temp_output_175_0 , ( 1.0 - temp_output_175_0 ) );
				float smoothstepResult186 = smoothstep( ( temp_output_182_0 - temp_output_183_0 ) , ( temp_output_182_0 + temp_output_183_0 ) , min( break184.x , break184.y ));
				float LINE_YZ246 = smoothstepResult186;
				float temp_output_198_0 = max( _CellSize , 0.001 );
				float temp_output_214_0 = ( _LineWidthMeters / temp_output_198_0 );
				float2 temp_output_202_0 = ( (ase_positionWS).xz / temp_output_198_0 );
				float2 break209 = fwidth( temp_output_202_0 );
				float temp_output_215_0 = ( max( break209.x , break209.y ) * 0.5 );
				float2 temp_output_204_0 = frac( temp_output_202_0 );
				float2 break216 = min( temp_output_204_0 , ( 1.0 - temp_output_204_0 ) );
				float smoothstepResult220 = smoothstep( ( temp_output_214_0 - temp_output_215_0 ) , ( temp_output_214_0 + temp_output_215_0 ) , min( break216.x , break216.y ));
				float LINE_XZ244 = smoothstepResult220;
				float temp_output_137_0 = max( _CellSize , 0.001 );
				float temp_output_146_0 = ( _LineWidthMeters / temp_output_137_0 );
				float2 temp_output_121_0 = ( (ase_positionWS).xy / temp_output_137_0 );
				float2 break151 = fwidth( temp_output_121_0 );
				float temp_output_153_0 = ( max( break151.x , break151.y ) * 0.5 );
				float2 temp_output_125_0 = frac( temp_output_121_0 );
				float2 break130 = min( temp_output_125_0 , ( 1.0 - temp_output_125_0 ) );
				float smoothstepResult147 = smoothstep( ( temp_output_146_0 - temp_output_153_0 ) , ( temp_output_146_0 + temp_output_153_0 ) , min( break130.x , break130.y ));
				float LINE_XY248 = smoothstepResult147;
				float temp_output_258_0 = ( 1.0 - ( ( ( break240.x * LINE_YZ246 ) + ( break240.y * LINE_XZ244 ) ) + ( break240.z * LINE_XY248 ) ) );
				float3 localASE_GetCenterEyeWS269 = ASE_GetCenterEyeWS();
				float3 worldToObj76 = mul( GetWorldToObjectMatrix(), float4( localASE_GetCenterEyeWS269, 1 ) ).xyz;
				float3 ase_objectScale = float3( length( GetObjectToWorldMatrix()[ 0 ].xyz ), length( GetObjectToWorldMatrix()[ 1 ].xyz ), length( GetObjectToWorldMatrix()[ 2 ].xyz ) );
				float3 temp_output_124_0 = ( ( abs( ( worldToObj76 - float3( 0, 0, 0 ) ) ) - float3( 0.5, 0.5, 0.5 ) ) * ase_objectScale );
				float3 break90 = temp_output_124_0;
				float clampResult110 = clamp( ( ( abs( ( min( max( max( break90.x , break90.y ) , break90.z ) , 0.0 ) + length( max( temp_output_124_0 , float3( 0,0,0 ) ) ) ) ) - _ShowDistance ) / max( _FadeBand , 0.0001 ) ) , 0.0 , 1.0 );
				float smoothstepResult111 = smoothstep( 0.0 , 1.0 , clampResult110);
				

				float3 BakedAlbedo = 0;
				float3 BakedEmission = 0;
				float Alpha = ( temp_output_258_0 * ( 1.0 - smoothstepResult111 ) );
				float AlphaClipThreshold = 0.5;

				#if defined( _ALPHATEST_ON )
					AlphaDiscard( Alpha, AlphaClipThreshold );
				#endif

				MetaInput metaInput = (MetaInput)0;
				metaInput.Albedo = BakedAlbedo;
				metaInput.Emission = BakedEmission;

				return MetaFragment(metaInput);
			}
			ENDHLSL
		}

		
		Pass
		{
			
			Name "SceneSelectionPass"
			Tags { "LightMode"="SceneSelectionPass" }

			Cull Off
			AlphaToMask Off

			HLSLPROGRAM

			#pragma multi_compile_local _ALPHATEST_ON
			#define _SURFACE_TYPE_TRANSPARENT 1
			#define ASE_VERSION 19903
			#define ASE_SRP_VERSION 170004


			#pragma vertex vert
			#pragma fragment frag

			#define ATTRIBUTES_NEED_NORMAL
			#define ATTRIBUTES_NEED_TANGENT
			#define SHADERPASS SHADERPASS_DEPTHONLY

			#include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
			#include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
			#include_with_pragmas "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRenderingKeywords.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRendering.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

			#define ASE_NEEDS_VERT_NORMAL
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl "


			struct Attributes
			{
				float4 positionOS : POSITION;
				half3 normalOS : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct PackedVaryings
			{
				float4 positionCS : SV_POSITION;
				float4 ase_texcoord : TEXCOORD0;
				float4 ase_texcoord1 : TEXCOORD1;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
			float _TriSharp;
			float _LineWidthMeters;
			float _CellSize;
			float _RedThreshold;
			float _BlueThreshold;
			float _ShowDistance;
			float _FadeBand;
			#ifdef ASE_TESSELLATION
				float _TessPhongStrength;
				float _TessValue;
				float _TessMin;
				float _TessMax;
				float _TessEdgeLength;
				float _TessMaxDisp;
			#endif
			CBUFFER_END

			

			float3 ASE_GetCenterEyeWS(  )
			{
				#if defined(UNITY_STEREO_INSTANCING_ENABLED) || defined(UNITY_STEREO_MULTIVIEW_ENABLED)
				    return 0.5 * (unity_StereoWorldSpaceCameraPos[0] + unity_StereoWorldSpaceCameraPos[1]);
				#else
				    return GetCameraPositionWS();
				#endif
			}
			

			int _ObjectId;
			int _PassValue;

			struct SurfaceDescription
			{
				float Alpha;
				float AlphaClipThreshold;
			};

			PackedVaryings VertexFunction(Attributes input  )
			{
				PackedVaryings output;
				ZERO_INITIALIZE(PackedVaryings, output);

				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

				float3 ase_normalWS = TransformObjectToWorldNormal( input.normalOS );
				output.ase_texcoord.xyz = ase_normalWS;
				float3 ase_positionWS = TransformObjectToWorld( ( input.positionOS ).xyz );
				output.ase_texcoord1.xyz = ase_positionWS;
				
				
				//setting value to unused interpolator channels and avoid initialization warnings
				output.ase_texcoord.w = 0;
				output.ase_texcoord1.w = 0;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = input.positionOS.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif

				float3 vertexValue = defaultVertexValue;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					input.positionOS.xyz = vertexValue;
				#else
					input.positionOS.xyz += vertexValue;
				#endif

				VertexPositionInputs vertexInput = GetVertexPositionInputs( input.positionOS.xyz );

				output.positionCS = vertexInput.positionCS;
				return output;
			}

			#if defined(ASE_TESSELLATION)
			struct VertexControl
			{
				float4 positionOS : INTERNALTESSPOS;
				half3 normalOS : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct TessellationFactors
			{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

			VertexControl vert ( Attributes input )
			{
				VertexControl output;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				output.positionOS = input.positionOS;
				output.normalOS = input.normalOS;
				
				return output;
			}

			TessellationFactors TessellationFunction (InputPatch<VertexControl,3> input)
			{
				TessellationFactors output;
				float4 tf = 1;
				float tessValue = _TessValue; float tessMin = _TessMin; float tessMax = _TessMax;
				float edgeLength = _TessEdgeLength; float tessMaxDisp = _TessMaxDisp;
				#if defined(ASE_FIXED_TESSELLATION)
				tf = FixedTess( tessValue );
				#elif defined(ASE_DISTANCE_TESSELLATION)
				tf = DistanceBasedTess(input[0].positionOS, input[1].positionOS, input[2].positionOS, tessValue, tessMin, tessMax, GetObjectToWorldMatrix(), _WorldSpaceCameraPos );
				#elif defined(ASE_LENGTH_TESSELLATION)
				tf = EdgeLengthBasedTess(input[0].positionOS, input[1].positionOS, input[2].positionOS, edgeLength, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams );
				#elif defined(ASE_LENGTH_CULL_TESSELLATION)
				tf = EdgeLengthBasedTessCull(input[0].positionOS, input[1].positionOS, input[2].positionOS, edgeLength, tessMaxDisp, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams, unity_CameraWorldClipPlanes );
				#endif
				output.edge[0] = tf.x; output.edge[1] = tf.y; output.edge[2] = tf.z; output.inside = tf.w;
				return output;
			}

			[domain("tri")]
			[partitioning("fractional_odd")]
			[outputtopology("triangle_cw")]
			[patchconstantfunc("TessellationFunction")]
			[outputcontrolpoints(3)]
			VertexControl HullFunction(InputPatch<VertexControl, 3> patch, uint id : SV_OutputControlPointID)
			{
				return patch[id];
			}

			[domain("tri")]
			PackedVaryings DomainFunction(TessellationFactors factors, OutputPatch<VertexControl, 3> patch, float3 bary : SV_DomainLocation)
			{
				Attributes output = (Attributes) 0;
				output.positionOS = patch[0].positionOS * bary.x + patch[1].positionOS * bary.y + patch[2].positionOS * bary.z;
				output.normalOS = patch[0].normalOS * bary.x + patch[1].normalOS * bary.y + patch[2].normalOS * bary.z;
				
				#if defined(ASE_PHONG_TESSELLATION)
				float3 pp[3];
				for (int i = 0; i < 3; ++i)
					pp[i] = output.positionOS.xyz - patch[i].normalOS * (dot(output.positionOS.xyz, patch[i].normalOS) - dot(patch[i].positionOS.xyz, patch[i].normalOS));
				float phongStrength = _TessPhongStrength;
				output.positionOS.xyz = phongStrength * (pp[0]*bary.x + pp[1]*bary.y + pp[2]*bary.z) + (1.0f-phongStrength) * output.positionOS.xyz;
				#endif
				UNITY_TRANSFER_INSTANCE_ID(patch[0], output);
				return VertexFunction(output);
			}
			#else
			PackedVaryings vert ( Attributes input )
			{
				return VertexFunction( input );
			}
			#endif

			half4 frag(PackedVaryings input ) : SV_Target
			{
				SurfaceDescription surfaceDescription = (SurfaceDescription)0;

				float3 ase_normalWS = input.ase_texcoord.xyz;
				float3 normalizeResult227 = normalize( ase_normalWS );
				float3 temp_cast_0 = (_TriSharp).xxx;
				float3 temp_output_228_0 = pow( abs( normalizeResult227 ) , temp_cast_0 );
				float dotResult233 = dot( temp_output_228_0 , float3( 1,1,1 ) );
				float3 break240 = ( temp_output_228_0 / max( dotResult233 , 0.0001 ) );
				float temp_output_191_0 = max( _CellSize , 0.001 );
				float temp_output_182_0 = ( _LineWidthMeters / temp_output_191_0 );
				float3 ase_positionWS = input.ase_texcoord1.xyz;
				float2 temp_output_174_0 = ( (ase_positionWS).yz / temp_output_191_0 );
				float2 break178 = fwidth( temp_output_174_0 );
				float temp_output_183_0 = ( max( break178.x , break178.y ) * 0.5 );
				float2 temp_output_175_0 = frac( temp_output_174_0 );
				float2 break184 = min( temp_output_175_0 , ( 1.0 - temp_output_175_0 ) );
				float smoothstepResult186 = smoothstep( ( temp_output_182_0 - temp_output_183_0 ) , ( temp_output_182_0 + temp_output_183_0 ) , min( break184.x , break184.y ));
				float LINE_YZ246 = smoothstepResult186;
				float temp_output_198_0 = max( _CellSize , 0.001 );
				float temp_output_214_0 = ( _LineWidthMeters / temp_output_198_0 );
				float2 temp_output_202_0 = ( (ase_positionWS).xz / temp_output_198_0 );
				float2 break209 = fwidth( temp_output_202_0 );
				float temp_output_215_0 = ( max( break209.x , break209.y ) * 0.5 );
				float2 temp_output_204_0 = frac( temp_output_202_0 );
				float2 break216 = min( temp_output_204_0 , ( 1.0 - temp_output_204_0 ) );
				float smoothstepResult220 = smoothstep( ( temp_output_214_0 - temp_output_215_0 ) , ( temp_output_214_0 + temp_output_215_0 ) , min( break216.x , break216.y ));
				float LINE_XZ244 = smoothstepResult220;
				float temp_output_137_0 = max( _CellSize , 0.001 );
				float temp_output_146_0 = ( _LineWidthMeters / temp_output_137_0 );
				float2 temp_output_121_0 = ( (ase_positionWS).xy / temp_output_137_0 );
				float2 break151 = fwidth( temp_output_121_0 );
				float temp_output_153_0 = ( max( break151.x , break151.y ) * 0.5 );
				float2 temp_output_125_0 = frac( temp_output_121_0 );
				float2 break130 = min( temp_output_125_0 , ( 1.0 - temp_output_125_0 ) );
				float smoothstepResult147 = smoothstep( ( temp_output_146_0 - temp_output_153_0 ) , ( temp_output_146_0 + temp_output_153_0 ) , min( break130.x , break130.y ));
				float LINE_XY248 = smoothstepResult147;
				float temp_output_258_0 = ( 1.0 - ( ( ( break240.x * LINE_YZ246 ) + ( break240.y * LINE_XZ244 ) ) + ( break240.z * LINE_XY248 ) ) );
				float3 localASE_GetCenterEyeWS269 = ASE_GetCenterEyeWS();
				float3 worldToObj76 = mul( GetWorldToObjectMatrix(), float4( localASE_GetCenterEyeWS269, 1 ) ).xyz;
				float3 ase_objectScale = float3( length( GetObjectToWorldMatrix()[ 0 ].xyz ), length( GetObjectToWorldMatrix()[ 1 ].xyz ), length( GetObjectToWorldMatrix()[ 2 ].xyz ) );
				float3 temp_output_124_0 = ( ( abs( ( worldToObj76 - float3( 0, 0, 0 ) ) ) - float3( 0.5, 0.5, 0.5 ) ) * ase_objectScale );
				float3 break90 = temp_output_124_0;
				float clampResult110 = clamp( ( ( abs( ( min( max( max( break90.x , break90.y ) , break90.z ) , 0.0 ) + length( max( temp_output_124_0 , float3( 0,0,0 ) ) ) ) ) - _ShowDistance ) / max( _FadeBand , 0.0001 ) ) , 0.0 , 1.0 );
				float smoothstepResult111 = smoothstep( 0.0 , 1.0 , clampResult110);
				

				surfaceDescription.Alpha = ( temp_output_258_0 * ( 1.0 - smoothstepResult111 ) );
				surfaceDescription.AlphaClipThreshold = 0.5;

				#if _ALPHATEST_ON
					float alphaClipThreshold = 0.01f;
					#if ALPHA_CLIP_THRESHOLD
						alphaClipThreshold = surfaceDescription.AlphaClipThreshold;
					#endif
					clip(surfaceDescription.Alpha - alphaClipThreshold);
				#endif

				half4 outColor = half4(_ObjectId, _PassValue, 1.0, 1.0);
				return outColor;
			}
			ENDHLSL
		}

		
		Pass
		{
			
			Name "ScenePickingPass"
			Tags { "LightMode"="Picking" }

			AlphaToMask Off

			HLSLPROGRAM

			#pragma multi_compile_local _ALPHATEST_ON
			#define _SURFACE_TYPE_TRANSPARENT 1
			#define ASE_VERSION 19903
			#define ASE_SRP_VERSION 170004


			#pragma vertex vert
			#pragma fragment frag

			#define ATTRIBUTES_NEED_NORMAL
			#define ATTRIBUTES_NEED_TANGENT

			#define SHADERPASS SHADERPASS_DEPTHONLY

			#include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
			#include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
			#include_with_pragmas "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRenderingKeywords.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRendering.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

			#if defined(LOD_FADE_CROSSFADE)
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

			#define ASE_NEEDS_VERT_NORMAL
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl "


			struct Attributes
			{
				float4 positionOS : POSITION;
				half3 normalOS : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct PackedVaryings
			{
				float4 positionCS : SV_POSITION;
				float4 ase_texcoord : TEXCOORD0;
				float4 ase_texcoord1 : TEXCOORD1;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
			float _TriSharp;
			float _LineWidthMeters;
			float _CellSize;
			float _RedThreshold;
			float _BlueThreshold;
			float _ShowDistance;
			float _FadeBand;
			#ifdef ASE_TESSELLATION
				float _TessPhongStrength;
				float _TessValue;
				float _TessMin;
				float _TessMax;
				float _TessEdgeLength;
				float _TessMaxDisp;
			#endif
			CBUFFER_END

			

			float3 ASE_GetCenterEyeWS(  )
			{
				#if defined(UNITY_STEREO_INSTANCING_ENABLED) || defined(UNITY_STEREO_MULTIVIEW_ENABLED)
				    return 0.5 * (unity_StereoWorldSpaceCameraPos[0] + unity_StereoWorldSpaceCameraPos[1]);
				#else
				    return GetCameraPositionWS();
				#endif
			}
			

			float4 _SelectionID;

			struct SurfaceDescription
			{
				float Alpha;
				float AlphaClipThreshold;
			};

			PackedVaryings VertexFunction(Attributes input  )
			{
				PackedVaryings output;
				ZERO_INITIALIZE(PackedVaryings, output);

				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

				float3 ase_normalWS = TransformObjectToWorldNormal( input.normalOS );
				output.ase_texcoord.xyz = ase_normalWS;
				float3 ase_positionWS = TransformObjectToWorld( ( input.positionOS ).xyz );
				output.ase_texcoord1.xyz = ase_positionWS;
				
				
				//setting value to unused interpolator channels and avoid initialization warnings
				output.ase_texcoord.w = 0;
				output.ase_texcoord1.w = 0;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = input.positionOS.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif

				float3 vertexValue = defaultVertexValue;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					input.positionOS.xyz = vertexValue;
				#else
					input.positionOS.xyz += vertexValue;
				#endif

				VertexPositionInputs vertexInput = GetVertexPositionInputs( input.positionOS.xyz );

				output.positionCS = vertexInput.positionCS;
				return output;
			}

			#if defined(ASE_TESSELLATION)
			struct VertexControl
			{
				float4 positionOS : INTERNALTESSPOS;
				half3 normalOS : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct TessellationFactors
			{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

			VertexControl vert ( Attributes input )
			{
				VertexControl output;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				output.positionOS = input.positionOS;
				output.normalOS = input.normalOS;
				
				return output;
			}

			TessellationFactors TessellationFunction (InputPatch<VertexControl,3> input)
			{
				TessellationFactors output;
				float4 tf = 1;
				float tessValue = _TessValue; float tessMin = _TessMin; float tessMax = _TessMax;
				float edgeLength = _TessEdgeLength; float tessMaxDisp = _TessMaxDisp;
				#if defined(ASE_FIXED_TESSELLATION)
				tf = FixedTess( tessValue );
				#elif defined(ASE_DISTANCE_TESSELLATION)
				tf = DistanceBasedTess(input[0].positionOS, input[1].positionOS, input[2].positionOS, tessValue, tessMin, tessMax, GetObjectToWorldMatrix(), _WorldSpaceCameraPos );
				#elif defined(ASE_LENGTH_TESSELLATION)
				tf = EdgeLengthBasedTess(input[0].positionOS, input[1].positionOS, input[2].positionOS, edgeLength, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams );
				#elif defined(ASE_LENGTH_CULL_TESSELLATION)
				tf = EdgeLengthBasedTessCull(input[0].positionOS, input[1].positionOS, input[2].positionOS, edgeLength, tessMaxDisp, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams, unity_CameraWorldClipPlanes );
				#endif
				output.edge[0] = tf.x; output.edge[1] = tf.y; output.edge[2] = tf.z; output.inside = tf.w;
				return output;
			}

			[domain("tri")]
			[partitioning("fractional_odd")]
			[outputtopology("triangle_cw")]
			[patchconstantfunc("TessellationFunction")]
			[outputcontrolpoints(3)]
			VertexControl HullFunction(InputPatch<VertexControl, 3> patch, uint id : SV_OutputControlPointID)
			{
				return patch[id];
			}

			[domain("tri")]
			PackedVaryings DomainFunction(TessellationFactors factors, OutputPatch<VertexControl, 3> patch, float3 bary : SV_DomainLocation)
			{
				Attributes output = (Attributes) 0;
				output.positionOS = patch[0].positionOS * bary.x + patch[1].positionOS * bary.y + patch[2].positionOS * bary.z;
				output.normalOS = patch[0].normalOS * bary.x + patch[1].normalOS * bary.y + patch[2].normalOS * bary.z;
				
				#if defined(ASE_PHONG_TESSELLATION)
				float3 pp[3];
				for (int i = 0; i < 3; ++i)
					pp[i] = output.positionOS.xyz - patch[i].normalOS * (dot(output.positionOS.xyz, patch[i].normalOS) - dot(patch[i].positionOS.xyz, patch[i].normalOS));
				float phongStrength = _TessPhongStrength;
				output.positionOS.xyz = phongStrength * (pp[0]*bary.x + pp[1]*bary.y + pp[2]*bary.z) + (1.0f-phongStrength) * output.positionOS.xyz;
				#endif
				UNITY_TRANSFER_INSTANCE_ID(patch[0], output);
				return VertexFunction(output);
			}
			#else
			PackedVaryings vert ( Attributes input )
			{
				return VertexFunction( input );
			}
			#endif

			half4 frag(PackedVaryings input ) : SV_Target
			{
				SurfaceDescription surfaceDescription = (SurfaceDescription)0;

				float3 ase_normalWS = input.ase_texcoord.xyz;
				float3 normalizeResult227 = normalize( ase_normalWS );
				float3 temp_cast_0 = (_TriSharp).xxx;
				float3 temp_output_228_0 = pow( abs( normalizeResult227 ) , temp_cast_0 );
				float dotResult233 = dot( temp_output_228_0 , float3( 1,1,1 ) );
				float3 break240 = ( temp_output_228_0 / max( dotResult233 , 0.0001 ) );
				float temp_output_191_0 = max( _CellSize , 0.001 );
				float temp_output_182_0 = ( _LineWidthMeters / temp_output_191_0 );
				float3 ase_positionWS = input.ase_texcoord1.xyz;
				float2 temp_output_174_0 = ( (ase_positionWS).yz / temp_output_191_0 );
				float2 break178 = fwidth( temp_output_174_0 );
				float temp_output_183_0 = ( max( break178.x , break178.y ) * 0.5 );
				float2 temp_output_175_0 = frac( temp_output_174_0 );
				float2 break184 = min( temp_output_175_0 , ( 1.0 - temp_output_175_0 ) );
				float smoothstepResult186 = smoothstep( ( temp_output_182_0 - temp_output_183_0 ) , ( temp_output_182_0 + temp_output_183_0 ) , min( break184.x , break184.y ));
				float LINE_YZ246 = smoothstepResult186;
				float temp_output_198_0 = max( _CellSize , 0.001 );
				float temp_output_214_0 = ( _LineWidthMeters / temp_output_198_0 );
				float2 temp_output_202_0 = ( (ase_positionWS).xz / temp_output_198_0 );
				float2 break209 = fwidth( temp_output_202_0 );
				float temp_output_215_0 = ( max( break209.x , break209.y ) * 0.5 );
				float2 temp_output_204_0 = frac( temp_output_202_0 );
				float2 break216 = min( temp_output_204_0 , ( 1.0 - temp_output_204_0 ) );
				float smoothstepResult220 = smoothstep( ( temp_output_214_0 - temp_output_215_0 ) , ( temp_output_214_0 + temp_output_215_0 ) , min( break216.x , break216.y ));
				float LINE_XZ244 = smoothstepResult220;
				float temp_output_137_0 = max( _CellSize , 0.001 );
				float temp_output_146_0 = ( _LineWidthMeters / temp_output_137_0 );
				float2 temp_output_121_0 = ( (ase_positionWS).xy / temp_output_137_0 );
				float2 break151 = fwidth( temp_output_121_0 );
				float temp_output_153_0 = ( max( break151.x , break151.y ) * 0.5 );
				float2 temp_output_125_0 = frac( temp_output_121_0 );
				float2 break130 = min( temp_output_125_0 , ( 1.0 - temp_output_125_0 ) );
				float smoothstepResult147 = smoothstep( ( temp_output_146_0 - temp_output_153_0 ) , ( temp_output_146_0 + temp_output_153_0 ) , min( break130.x , break130.y ));
				float LINE_XY248 = smoothstepResult147;
				float temp_output_258_0 = ( 1.0 - ( ( ( break240.x * LINE_YZ246 ) + ( break240.y * LINE_XZ244 ) ) + ( break240.z * LINE_XY248 ) ) );
				float3 localASE_GetCenterEyeWS269 = ASE_GetCenterEyeWS();
				float3 worldToObj76 = mul( GetWorldToObjectMatrix(), float4( localASE_GetCenterEyeWS269, 1 ) ).xyz;
				float3 ase_objectScale = float3( length( GetObjectToWorldMatrix()[ 0 ].xyz ), length( GetObjectToWorldMatrix()[ 1 ].xyz ), length( GetObjectToWorldMatrix()[ 2 ].xyz ) );
				float3 temp_output_124_0 = ( ( abs( ( worldToObj76 - float3( 0, 0, 0 ) ) ) - float3( 0.5, 0.5, 0.5 ) ) * ase_objectScale );
				float3 break90 = temp_output_124_0;
				float clampResult110 = clamp( ( ( abs( ( min( max( max( break90.x , break90.y ) , break90.z ) , 0.0 ) + length( max( temp_output_124_0 , float3( 0,0,0 ) ) ) ) ) - _ShowDistance ) / max( _FadeBand , 0.0001 ) ) , 0.0 , 1.0 );
				float smoothstepResult111 = smoothstep( 0.0 , 1.0 , clampResult110);
				

				surfaceDescription.Alpha = ( temp_output_258_0 * ( 1.0 - smoothstepResult111 ) );
				surfaceDescription.AlphaClipThreshold = 0.5;

				#if _ALPHATEST_ON
					float alphaClipThreshold = 0.01f;
					#if ALPHA_CLIP_THRESHOLD
						alphaClipThreshold = surfaceDescription.AlphaClipThreshold;
					#endif
					clip(surfaceDescription.Alpha - alphaClipThreshold);
				#endif

				half4 outColor = 0;
				outColor = _SelectionID;

				return outColor;
			}

			ENDHLSL
		}

		
		Pass
		{
			
			Name "DepthNormals"
			Tags { "LightMode"="DepthNormalsOnly" }

			ZTest LEqual
			ZWrite On

			HLSLPROGRAM

        	#pragma multi_compile_local _ALPHATEST_ON
        	#pragma multi_compile_instancing
        	#define _SURFACE_TYPE_TRANSPARENT 1
        	#define ASE_VERSION 19903
        	#define ASE_SRP_VERSION 170004


        	#pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT

			#pragma vertex vert
			#pragma fragment frag

			#define ATTRIBUTES_NEED_NORMAL
			#define ATTRIBUTES_NEED_TANGENT
			#define VARYINGS_NEED_NORMAL_WS

			#define SHADERPASS SHADERPASS_DEPTHNORMALSONLY

			#include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
			#include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
			#include_with_pragmas "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRenderingKeywords.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRendering.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

            #if defined(LOD_FADE_CROSSFADE)
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

			#define ASE_NEEDS_WORLD_NORMAL
			#define ASE_NEEDS_FRAG_WORLD_NORMAL
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl "


			#if defined(ASE_EARLY_Z_DEPTH_OPTIMIZE) && (SHADER_TARGET >= 45)
				#define ASE_SV_DEPTH SV_DepthLessEqual
				#define ASE_SV_POSITION_QUALIFIERS linear noperspective centroid
			#else
				#define ASE_SV_DEPTH SV_Depth
				#define ASE_SV_POSITION_QUALIFIERS
			#endif

			struct Attributes
			{
				float4 positionOS : POSITION;
				half3 normalOS : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct PackedVaryings
			{
				ASE_SV_POSITION_QUALIFIERS float4 positionCS : SV_POSITION;
				half3 normalWS : TEXCOORD0;
				float4 ase_texcoord1 : TEXCOORD1;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
			float _TriSharp;
			float _LineWidthMeters;
			float _CellSize;
			float _RedThreshold;
			float _BlueThreshold;
			float _ShowDistance;
			float _FadeBand;
			#ifdef ASE_TESSELLATION
				float _TessPhongStrength;
				float _TessValue;
				float _TessMin;
				float _TessMax;
				float _TessEdgeLength;
				float _TessMaxDisp;
			#endif
			CBUFFER_END

			

			float3 ASE_GetCenterEyeWS(  )
			{
				#if defined(UNITY_STEREO_INSTANCING_ENABLED) || defined(UNITY_STEREO_MULTIVIEW_ENABLED)
				    return 0.5 * (unity_StereoWorldSpaceCameraPos[0] + unity_StereoWorldSpaceCameraPos[1]);
				#else
				    return GetCameraPositionWS();
				#endif
			}
			

			struct SurfaceDescription
			{
				float Alpha;
				float AlphaClipThreshold;
			};

			PackedVaryings VertexFunction( Attributes input  )
			{
				PackedVaryings output;
				ZERO_INITIALIZE(PackedVaryings, output);

				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

				float3 ase_positionWS = TransformObjectToWorld( ( input.positionOS ).xyz );
				output.ase_texcoord1.xyz = ase_positionWS;
				
				
				//setting value to unused interpolator channels and avoid initialization warnings
				output.ase_texcoord1.w = 0;
				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = input.positionOS.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif

				float3 vertexValue = defaultVertexValue;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					input.positionOS.xyz = vertexValue;
				#else
					input.positionOS.xyz += vertexValue;
				#endif

				input.normalOS = input.normalOS;

				VertexPositionInputs vertexInput = GetVertexPositionInputs( input.positionOS.xyz );
				VertexNormalInputs normalInput = GetVertexNormalInputs( input.normalOS );

				output.positionCS = vertexInput.positionCS;
				output.normalWS = normalInput.normalWS;
				return output;
			}

			#if defined(ASE_TESSELLATION)
			struct VertexControl
			{
				float4 positionOS : INTERNALTESSPOS;
				half3 normalOS : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct TessellationFactors
			{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

			VertexControl vert ( Attributes input )
			{
				VertexControl output;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				output.positionOS = input.positionOS;
				output.normalOS = input.normalOS;
				
				return output;
			}

			TessellationFactors TessellationFunction (InputPatch<VertexControl,3> input)
			{
				TessellationFactors output;
				float4 tf = 1;
				float tessValue = _TessValue; float tessMin = _TessMin; float tessMax = _TessMax;
				float edgeLength = _TessEdgeLength; float tessMaxDisp = _TessMaxDisp;
				#if defined(ASE_FIXED_TESSELLATION)
				tf = FixedTess( tessValue );
				#elif defined(ASE_DISTANCE_TESSELLATION)
				tf = DistanceBasedTess(input[0].positionOS, input[1].positionOS, input[2].positionOS, tessValue, tessMin, tessMax, GetObjectToWorldMatrix(), _WorldSpaceCameraPos );
				#elif defined(ASE_LENGTH_TESSELLATION)
				tf = EdgeLengthBasedTess(input[0].positionOS, input[1].positionOS, input[2].positionOS, edgeLength, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams );
				#elif defined(ASE_LENGTH_CULL_TESSELLATION)
				tf = EdgeLengthBasedTessCull(input[0].positionOS, input[1].positionOS, input[2].positionOS, edgeLength, tessMaxDisp, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams, unity_CameraWorldClipPlanes );
				#endif
				output.edge[0] = tf.x; output.edge[1] = tf.y; output.edge[2] = tf.z; output.inside = tf.w;
				return output;
			}

			[domain("tri")]
			[partitioning("fractional_odd")]
			[outputtopology("triangle_cw")]
			[patchconstantfunc("TessellationFunction")]
			[outputcontrolpoints(3)]
			VertexControl HullFunction(InputPatch<VertexControl, 3> patch, uint id : SV_OutputControlPointID)
			{
				return patch[id];
			}

			[domain("tri")]
			PackedVaryings DomainFunction(TessellationFactors factors, OutputPatch<VertexControl, 3> patch, float3 bary : SV_DomainLocation)
			{
				Attributes output = (Attributes) 0;
				output.positionOS = patch[0].positionOS * bary.x + patch[1].positionOS * bary.y + patch[2].positionOS * bary.z;
				output.normalOS = patch[0].normalOS * bary.x + patch[1].normalOS * bary.y + patch[2].normalOS * bary.z;
				
				#if defined(ASE_PHONG_TESSELLATION)
				float3 pp[3];
				for (int i = 0; i < 3; ++i)
					pp[i] = output.positionOS.xyz - patch[i].normalOS * (dot(output.positionOS.xyz, patch[i].normalOS) - dot(patch[i].positionOS.xyz, patch[i].normalOS));
				float phongStrength = _TessPhongStrength;
				output.positionOS.xyz = phongStrength * (pp[0]*bary.x + pp[1]*bary.y + pp[2]*bary.z) + (1.0f-phongStrength) * output.positionOS.xyz;
				#endif
				UNITY_TRANSFER_INSTANCE_ID(patch[0], output);
				return VertexFunction(output);
			}
			#else
			PackedVaryings vert ( Attributes input )
			{
				return VertexFunction( input );
			}
			#endif

			void frag(PackedVaryings input
						, out half4 outNormalWS : SV_Target0
						#if defined( ASE_DEPTH_WRITE_ON )
						,out float outputDepth : ASE_SV_DEPTH
						#endif
						#ifdef _WRITE_RENDERING_LAYERS
						, out float4 outRenderingLayers : SV_Target1
						#endif
						 )
			{
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX( input );

				half3 NormalWS = normalize( input.normalWS );
				float4 ScreenPosNorm = float4( GetNormalizedScreenSpaceUV( input.positionCS ), input.positionCS.zw );
				float4 ClipPos = ComputeClipSpacePosition( ScreenPosNorm.xy, input.positionCS.z ) * input.positionCS.w;
				float4 ScreenPos = ComputeScreenPos( ClipPos );

				float3 normalizeResult227 = normalize( NormalWS );
				float3 temp_cast_0 = (_TriSharp).xxx;
				float3 temp_output_228_0 = pow( abs( normalizeResult227 ) , temp_cast_0 );
				float dotResult233 = dot( temp_output_228_0 , float3( 1,1,1 ) );
				float3 break240 = ( temp_output_228_0 / max( dotResult233 , 0.0001 ) );
				float temp_output_191_0 = max( _CellSize , 0.001 );
				float temp_output_182_0 = ( _LineWidthMeters / temp_output_191_0 );
				float3 ase_positionWS = input.ase_texcoord1.xyz;
				float2 temp_output_174_0 = ( (ase_positionWS).yz / temp_output_191_0 );
				float2 break178 = fwidth( temp_output_174_0 );
				float temp_output_183_0 = ( max( break178.x , break178.y ) * 0.5 );
				float2 temp_output_175_0 = frac( temp_output_174_0 );
				float2 break184 = min( temp_output_175_0 , ( 1.0 - temp_output_175_0 ) );
				float smoothstepResult186 = smoothstep( ( temp_output_182_0 - temp_output_183_0 ) , ( temp_output_182_0 + temp_output_183_0 ) , min( break184.x , break184.y ));
				float LINE_YZ246 = smoothstepResult186;
				float temp_output_198_0 = max( _CellSize , 0.001 );
				float temp_output_214_0 = ( _LineWidthMeters / temp_output_198_0 );
				float2 temp_output_202_0 = ( (ase_positionWS).xz / temp_output_198_0 );
				float2 break209 = fwidth( temp_output_202_0 );
				float temp_output_215_0 = ( max( break209.x , break209.y ) * 0.5 );
				float2 temp_output_204_0 = frac( temp_output_202_0 );
				float2 break216 = min( temp_output_204_0 , ( 1.0 - temp_output_204_0 ) );
				float smoothstepResult220 = smoothstep( ( temp_output_214_0 - temp_output_215_0 ) , ( temp_output_214_0 + temp_output_215_0 ) , min( break216.x , break216.y ));
				float LINE_XZ244 = smoothstepResult220;
				float temp_output_137_0 = max( _CellSize , 0.001 );
				float temp_output_146_0 = ( _LineWidthMeters / temp_output_137_0 );
				float2 temp_output_121_0 = ( (ase_positionWS).xy / temp_output_137_0 );
				float2 break151 = fwidth( temp_output_121_0 );
				float temp_output_153_0 = ( max( break151.x , break151.y ) * 0.5 );
				float2 temp_output_125_0 = frac( temp_output_121_0 );
				float2 break130 = min( temp_output_125_0 , ( 1.0 - temp_output_125_0 ) );
				float smoothstepResult147 = smoothstep( ( temp_output_146_0 - temp_output_153_0 ) , ( temp_output_146_0 + temp_output_153_0 ) , min( break130.x , break130.y ));
				float LINE_XY248 = smoothstepResult147;
				float temp_output_258_0 = ( 1.0 - ( ( ( break240.x * LINE_YZ246 ) + ( break240.y * LINE_XZ244 ) ) + ( break240.z * LINE_XY248 ) ) );
				float3 localASE_GetCenterEyeWS269 = ASE_GetCenterEyeWS();
				float3 worldToObj76 = mul( GetWorldToObjectMatrix(), float4( localASE_GetCenterEyeWS269, 1 ) ).xyz;
				float3 ase_objectScale = float3( length( GetObjectToWorldMatrix()[ 0 ].xyz ), length( GetObjectToWorldMatrix()[ 1 ].xyz ), length( GetObjectToWorldMatrix()[ 2 ].xyz ) );
				float3 temp_output_124_0 = ( ( abs( ( worldToObj76 - float3( 0, 0, 0 ) ) ) - float3( 0.5, 0.5, 0.5 ) ) * ase_objectScale );
				float3 break90 = temp_output_124_0;
				float clampResult110 = clamp( ( ( abs( ( min( max( max( break90.x , break90.y ) , break90.z ) , 0.0 ) + length( max( temp_output_124_0 , float3( 0,0,0 ) ) ) ) ) - _ShowDistance ) / max( _FadeBand , 0.0001 ) ) , 0.0 , 1.0 );
				float smoothstepResult111 = smoothstep( 0.0 , 1.0 , clampResult110);
				

				float Alpha = ( temp_output_258_0 * ( 1.0 - smoothstepResult111 ) );
				float AlphaClipThreshold = 0.5;

				#if defined( ASE_DEPTH_WRITE_ON )
					float DeviceDepth = input.positionCS.z;
				#endif

				#ifdef _ALPHATEST_ON
					clip(Alpha - AlphaClipThreshold);
				#endif

				#if defined(LOD_FADE_CROSSFADE)
					LODFadeCrossFade( input.positionCS );
				#endif

				#if defined( ASE_DEPTH_WRITE_ON )
					outputDepth = DeviceDepth;
				#endif

				#if defined(_GBUFFER_NORMALS_OCT)
					float2 octNormalWS = PackNormalOctQuadEncode(NormalWS);
					float2 remappedOctNormalWS = saturate(octNormalWS * 0.5 + 0.5);
					half3 packedNormalWS = PackFloat2To888(remappedOctNormalWS);
					outNormalWS = half4(packedNormalWS, 0.0);
				#else
					outNormalWS = half4(NormalizeNormalPerPixel( NormalWS ), 0.0);
				#endif

				#ifdef _WRITE_RENDERING_LAYERS
					uint renderingLayers = GetMeshRenderingLayer();
					outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
				#endif
			}
			ENDHLSL
		}

		
		Pass
		{
			
			Name "GBuffer"
			Tags { "LightMode"="UniversalGBuffer" }

			Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
			ZWrite Off
			ZTest LEqual
			Offset 0 , 0
			ColorMask RGBA

			

			HLSLPROGRAM

			
            #pragma multi_compile_local _ALPHATEST_ON
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #define _SURFACE_TYPE_TRANSPARENT 1
            #define ASE_VERSION 19903
            #define ASE_SRP_VERSION 170004


			
            #pragma multi_compile _ DOTS_INSTANCING_ON
		

			#pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
			#pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
			#pragma multi_compile_fragment _ _RENDER_PASS_ENABLED

			
            #pragma multi_compile_fragment _ _WRITE_RENDERING_LAYERS
		

			#pragma vertex vert
			#pragma fragment frag

			#define SHADERPASS SHADERPASS_GBUFFER

			

			

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"

			
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRendering.hlsl"
           

			
            #if ASE_SRP_VERSION >=140009
			#include_with_pragmas "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRenderingKeywords.hlsl"
			#endif
		

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

			#if defined(LOD_FADE_CROSSFADE)
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

			#if defined(UNITY_INSTANCING_ENABLED) && defined(_TERRAIN_INSTANCED_PERPIXEL_NORMAL)
				#define ENABLE_TERRAIN_PERPIXEL_NORMAL
			#endif

			

			#if defined(ASE_EARLY_Z_DEPTH_OPTIMIZE) && (SHADER_TARGET >= 45)
				#define ASE_SV_DEPTH SV_DepthLessEqual
				#define ASE_SV_POSITION_QUALIFIERS linear noperspective centroid
			#else
				#define ASE_SV_DEPTH SV_Depth
				#define ASE_SV_POSITION_QUALIFIERS
			#endif

			struct Attributes
			{
				float4 positionOS : POSITION;
				half3 normalOS : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct PackedVaryings
			{
				ASE_SV_POSITION_QUALIFIERS float4 positionCS : SV_POSITION;
				float3 positionWS : TEXCOORD0;
				half3 normalWS : TEXCOORD1;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
			float _TriSharp;
			float _LineWidthMeters;
			float _CellSize;
			float _RedThreshold;
			float _BlueThreshold;
			float _ShowDistance;
			float _FadeBand;
			#ifdef ASE_TRANSMISSION
				float _TransmissionShadow;
			#endif
			#ifdef ASE_TRANSLUCENCY
				float _TransStrength;
				float _TransNormal;
				float _TransScattering;
				float _TransDirect;
				float _TransAmbient;
				float _TransShadow;
			#endif
			#ifdef ASE_TESSELLATION
				float _TessPhongStrength;
				float _TessValue;
				float _TessMin;
				float _TessMax;
				float _TessEdgeLength;
				float _TessMaxDisp;
			#endif
			CBUFFER_END

			#ifdef SCENEPICKINGPASS
				float4 _SelectionID;
			#endif

			#ifdef SCENESELECTIONPASS
				int _ObjectId;
				int _PassValue;
			#endif

			

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"

			
			PackedVaryings VertexFunction( Attributes input  )
			{
				PackedVaryings output = (PackedVaryings)0;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

				
				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = input.positionOS.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif

				float3 vertexValue = defaultVertexValue;

				#ifdef ASE_ABSOLUTE_VERTEX_POS
					input.positionOS.xyz = vertexValue;
				#else
					input.positionOS.xyz += vertexValue;
				#endif

				VertexPositionInputs vertexInput = GetVertexPositionInputs( input.positionOS.xyz );
				VertexNormalInputs normalInput = GetVertexNormalInputs( input.normalOS );

				output.positionCS = vertexInput.positionCS;
				output.positionWS = vertexInput.positionWS;
				output.normalWS = normalInput.normalWS;
				return output;
			}

			#if defined(ASE_TESSELLATION)
			struct VertexControl
			{
				float4 positionOS : INTERNALTESSPOS;
				half3 normalOS : NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct TessellationFactors
			{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

			VertexControl vert ( Attributes input )
			{
				VertexControl output;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				output.positionOS = input.positionOS;
				output.normalOS = input.normalOS;
				
				return output;
			}

			TessellationFactors TessellationFunction (InputPatch<VertexControl,3> input)
			{
				TessellationFactors output;
				float4 tf = 1;
				float tessValue = _TessValue; float tessMin = _TessMin; float tessMax = _TessMax;
				float edgeLength = _TessEdgeLength; float tessMaxDisp = _TessMaxDisp;
				#if defined(ASE_FIXED_TESSELLATION)
				tf = FixedTess( tessValue );
				#elif defined(ASE_DISTANCE_TESSELLATION)
				tf = DistanceBasedTess(input[0].positionOS, input[1].positionOS, input[2].positionOS, tessValue, tessMin, tessMax, GetObjectToWorldMatrix(), _WorldSpaceCameraPos );
				#elif defined(ASE_LENGTH_TESSELLATION)
				tf = EdgeLengthBasedTess(input[0].positionOS, input[1].positionOS, input[2].positionOS, edgeLength, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams );
				#elif defined(ASE_LENGTH_CULL_TESSELLATION)
				tf = EdgeLengthBasedTessCull(input[0].positionOS, input[1].positionOS, input[2].positionOS, edgeLength, tessMaxDisp, GetObjectToWorldMatrix(), _WorldSpaceCameraPos, _ScreenParams, unity_CameraWorldClipPlanes );
				#endif
				output.edge[0] = tf.x; output.edge[1] = tf.y; output.edge[2] = tf.z; output.inside = tf.w;
				return output;
			}

			[domain("tri")]
			[partitioning("fractional_odd")]
			[outputtopology("triangle_cw")]
			[patchconstantfunc("TessellationFunction")]
			[outputcontrolpoints(3)]
			VertexControl HullFunction(InputPatch<VertexControl, 3> patch, uint id : SV_OutputControlPointID)
			{
				return patch[id];
			}

			[domain("tri")]
			PackedVaryings DomainFunction(TessellationFactors factors, OutputPatch<VertexControl, 3> patch, float3 bary : SV_DomainLocation)
			{
				Attributes output = (Attributes) 0;
				output.positionOS = patch[0].positionOS * bary.x + patch[1].positionOS * bary.y + patch[2].positionOS * bary.z;
				output.normalOS = patch[0].normalOS * bary.x + patch[1].normalOS * bary.y + patch[2].normalOS * bary.z;
				
				#if defined(ASE_PHONG_TESSELLATION)
				float3 pp[3];
				for (int i = 0; i < 3; ++i)
					pp[i] = output.positionOS.xyz - patch[i].normalOS * (dot(output.positionOS.xyz, patch[i].normalOS) - dot(patch[i].positionOS.xyz, patch[i].normalOS));
				float phongStrength = _TessPhongStrength;
				output.positionOS.xyz = phongStrength * (pp[0]*bary.x + pp[1]*bary.y + pp[2]*bary.z) + (1.0f-phongStrength) * output.positionOS.xyz;
				#endif
				UNITY_TRANSFER_INSTANCE_ID(patch[0], output);
				return VertexFunction(output);
			}
			#else
			PackedVaryings vert ( Attributes input )
			{
				return VertexFunction( input );
			}
			#endif

			FragmentOutput frag ( PackedVaryings input
								#if defined( ASE_DEPTH_WRITE_ON )
								,out float outputDepth : ASE_SV_DEPTH
								#endif
								 )
			{
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

				#if defined(LOD_FADE_CROSSFADE)
					LODFadeCrossFade( input.positionCS );
				#endif

				float3 PositionWS = input.positionWS;
				float3 ViewDirWS = GetWorldSpaceNormalizeViewDir( PositionWS );
				float4 ScreenPosNorm = float4( GetNormalizedScreenSpaceUV( input.positionCS ), input.positionCS.zw );
				float4 ClipPos = ComputeClipSpacePosition( ScreenPosNorm.xy, input.positionCS.z ) * input.positionCS.w;
				float4 ScreenPos = ComputeScreenPos( ClipPos );
				half3 NormalWS = normalize( input.normalWS );

				

				float3 Color = float3(0.5, 0.5, 0.5);
				float Alpha = 1;
				float AlphaClipThreshold = 0.5;
				float AlphaClipThresholdShadow = 0.5;

				#if defined( ASE_DEPTH_WRITE_ON )
					float DeviceDepth = input.positionCS.z;
				#endif

				#ifdef _ALPHATEST_ON
					clip(Alpha - AlphaClipThreshold);
				#endif

				InputData inputData = (InputData)0;
				inputData.positionWS = PositionWS;
				inputData.positionCS = float4( input.positionCS.xy, ClipPos.zw / ClipPos.w );
				inputData.normalizedScreenSpaceUV = ScreenPosNorm.xy;
				inputData.normalWS = NormalWS;
				inputData.viewDirectionWS = ViewDirWS;

				#if defined(_DBUFFER)
					ApplyDecalToBaseColor(input.positionCS, Color);
				#endif

				#if defined( ASE_DEPTH_WRITE_ON )
					outputDepth = DeviceDepth;
				#endif

				SurfaceData surfaceData = (SurfaceData)0;
				surfaceData.albedo = Color;
				surfaceData.alpha = Alpha;

			#if defined( _SCREEN_SPACE_OCCLUSION ) // GBuffer never has transparents
				float2 normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV( input.positionCS );
				AmbientOcclusionFactor aoFactor = GetScreenSpaceAmbientOcclusion( normalizedScreenSpaceUV );
				surfaceData.occlusion = aoFactor.directAmbientOcclusion;
			#else
				surfaceData.occlusion = 1;
			#endif

				return SurfaceDataToGbuffer( surfaceData, inputData, float3( 0, 0, 0 ), kLightingInvalid );
			}

			ENDHLSL
		}
		
	}
	
	CustomEditor "UnityEditor.ShaderGraphUnlitGUI"
	FallBack "Hidden/Shader Graph/FallbackError"
	
	Fallback Off
}
/*ASEBEGIN
Version=19903
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;163;-6532.086,-2069.564;Inherit;False;2008.443;1152.835;;14;188;187;186;184;177;172;171;170;169;168;167;166;165;164;LINE YZ;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;192;-6565.321,-3315.707;Inherit;False;2008.443;1152.835;;14;220;219;218;216;213;208;207;206;203;201;200;197;194;193;LINE XZ;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;161;-6518.725,-796.3185;Inherit;False;2008.443;1152.835;;14;155;156;147;130;127;143;148;142;154;160;141;145;139;135;LINE XY;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;85;-3936.259,646.6582;Inherit;False;571.7919;256.113;Pos Camera;2;76;269;Cam OS;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;86;-3547.456,990.4603;Inherit;False;540.5917;236.6131;;3;78;77;71;(p);1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;164;-6410.665,-1917.875;Inherit;False;517.2917;244.2134;;2;189;173;wpYZ;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;193;-6443.9,-3164.018;Inherit;False;517.2917;244.2134;;2;199;195;wpXZ;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;139;-6305.305,-368.6297;Inherit;False;296.2917;203.2134;;2;137;120;Cell;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;165;-6318.665,-1641.874;Inherit;False;296.2917;203.2134;;1;191;Cell;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;194;-6351.9,-2888.017;Inherit;False;296.2917;203.2134;;1;198;Cell;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;88;-3454.459,1308.158;Inherit;False;456.0917;286.0132;q_pre;2;79;72;q;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;135;-6397.305,-644.6299;Inherit;False;517.2917;244.2134;;2;134;119;wpXY;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;166;-5930.665,-1629.873;Inherit;False;165.2917;169.2134;;1;174;uvCell;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;197;-5963.9,-2876.016;Inherit;False;165.2917;169.2134;;1;202;uvCell;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;167;-5722.666,-1629.873;Inherit;False;152.2917;141.2134;;1;175;f;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;168;-5866.665,-1373.874;Inherit;False;293.2917;167.2134;;1;176;fw;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;145;-5917.305,-356.6297;Inherit;False;165.2917;169.2134;;1;121;uvCell;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;200;-5755.9,-2876.016;Inherit;False;152.2917;141.2134;;1;204;f;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;201;-5899.9,-2620.017;Inherit;False;293.2917;167.2134;;1;205;fw;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;223;-3104.374,-828.2705;Inherit;False;501.2917;244.2134;;3;221;227;222;nAbs;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;92;-2752.988,1183.209;Inherit;False;344.2917;187.2134;;2;91;90;M1;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;169;-5690.665,-1149.875;Inherit;False;445.2917;204.2134;;3;183;180;178;aa;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;141;-5709.305,-356.6297;Inherit;False;152.2917;141.2134;;1;125;f;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;160;-5853.305,-100.6294;Inherit;False;293.2917;167.2134;;1;159;fw;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;203;-5723.9,-2396.018;Inherit;False;445.2917;204.2134;;3;215;210;209;aa;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;170;-5354.665,-1629.873;Inherit;False;152.2917;141.2134;;1;179;a;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;154;-5677.305,123.3688;Inherit;False;445.2917;204.2134;;3;153;152;151;aa;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;206;-5387.9,-2876.016;Inherit;False;152.2917;141.2134;;1;212;a;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;232;-2735.646,-494.7952;Inherit;False;390.2917;241.2134;;2;229;228;wSharp;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;171;-6442.665,-1293.875;Inherit;False;445.2917;204.2134;;2;182;133;lineWidthFrac;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;207;-6475.9,-2540.018;Inherit;False;445.2917;204.2134;;1;214;lineWidthFrac;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;89;-2569.773,1488.948;Inherit;False;344.2917;187.2134;;2;81;80;Outside;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;93;-2371.289,1197.193;Inherit;False;205.2917;156.2134;;1;95;M2;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;142;-5341.305,-356.6297;Inherit;False;152.2917;141.2134;;1;126;a;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;148;-6429.305,-20.63049;Inherit;False;445.2917;204.2134;;1;146;lineWidthFrac;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;97;-2130.79,1210.578;Inherit;False;205.2917;156.2134;;1;96;Inside;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;172;-4984.329,-1480.499;Inherit;False;152.2917;141.2134;;1;185;dist;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;213;-5017.564,-2726.642;Inherit;False;152.2917;141.2134;;1;217;dist;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;236;-2303.646,-484.7952;Inherit;False;151.2917;176.2134;;1;233;Sum;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;100;-1986.232,1489.409;Inherit;False;205.2917;156.2134;;1;99;SDF;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;143;-4970.969,-207.2553;Inherit;False;152.2917;141.2134;;1;129;dist;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;237;-2131.646,-486.7952;Inherit;False;151.2917;176.2134;evita /0;1;235;SumSafe;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;102;-1730.232,1491.409;Inherit;False;205.2917;156.2134;;1;101;surfDist;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;108;-1480.504,1916.619;Inherit;False;806.2917;200.2134;;4;110;73;106;107;t;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;104;-1617.039,1698.956;Inherit;False;337.2917;167.2134;;2;103;105;d;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;239;-1916.046,-545.095;Inherit;False;151.2917;176.2134;;1;238;w;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;251;-1559.974,-717.0753;Inherit;False;407.2917;184.2134;;2;241;247;mX;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;252;-1557.974,-504.0753;Inherit;False;407.2917;184.2134;;2;245;242;mY;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;254;-1554.974,-279.0753;Inherit;False;407.2917;184.2134;;2;249;243;mZ;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;255;-1040.974,-650.0753;Inherit;False;197.2917;184.2134;;1;250;tmp;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;112;-643.6821,1912.771;Inherit;False;223.2917;197.2134;;1;111;s;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;257;-843.9742,-421.0753;Inherit;False;197.2917;184.2134;;1;256;blend;1,1,1,1;0;0
Node;AmplifyShaderEditor.Vector3Node, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;71;-3531.456,1070.46;Inherit;False;Constant;_BoundsCenterOS;BoundsCenterOS;6;0;Create;True;0;0;0;False;0;False;0,0,0;0,0,0;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.TransformPositionNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;76;-3601.259,721.6581;Inherit;False;World;Object;False;Fast;True;1;0;FLOAT3;0,0,0;False;5;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleSubtractOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;77;-3307.456,1054.46;Inherit;False;2;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.WorldPosInputsNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;173;-6378.665,-1853.875;Inherit;False;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.WorldPosInputsNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;195;-6411.9,-3100.018;Inherit;False;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.RangedFloatNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;120;-6287.305,-314.6297;Inherit;False;Property;_CellSize;CellSize;4;0;Create;True;0;0;0;False;0;False;0;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.AbsOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;78;-3147.456,1070.46;Inherit;False;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.Vector3Node, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;72;-3412.437,1426.13;Inherit;False;Constant;_BoundsExtendsOS;BoundsExtendsOS;7;0;Create;True;0;0;0;False;0;False;0.5,0.5,0.5;0,0,0;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.SimpleMaxOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;191;-6140.665,-1555.874;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0.001;False;1;FLOAT;0
Node;AmplifyShaderEditor.ComponentMaskNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;189;-6154.665,-1837.875;Inherit;False;False;True;True;True;1;0;FLOAT3;0,0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.WorldPosInputsNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;119;-6365.305,-580.6299;Inherit;False;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.SimpleMaxOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;198;-6173.9,-2802.017;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0.001;False;1;FLOAT;0
Node;AmplifyShaderEditor.ComponentMaskNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;199;-6187.9,-3084.018;Inherit;False;True;False;True;True;1;0;FLOAT3;0,0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleSubtractOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;79;-3166.461,1404.158;Inherit;False;2;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.ObjectScaleNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;123;-3220.689,1673.408;Inherit;False;False;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.SimpleDivideOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;174;-5898.665,-1597.873;Inherit;False;2;0;FLOAT2;0,0;False;1;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleMaxOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;137;-6127.305,-282.6299;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0.001;False;1;FLOAT;0
Node;AmplifyShaderEditor.ComponentMaskNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;134;-6141.305,-564.63;Inherit;False;True;True;False;True;1;0;FLOAT3;0,0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleDivideOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;202;-5931.9,-2844.016;Inherit;False;2;0;FLOAT2;0,0;False;1;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;124;-2917.181,1528.874;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.FractNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;175;-5706.666,-1581.874;Inherit;False;1;0;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.FWidthOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;176;-5818.665,-1293.875;Inherit;False;1;0;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleDivideOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;121;-5885.305,-324.6299;Inherit;False;2;0;FLOAT2;0,0;False;1;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.FractNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;204;-5739.9,-2828.017;Inherit;False;1;0;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.FWidthOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;205;-5851.9,-2540.018;Inherit;False;1;0;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.WorldNormalVector, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;221;-3080.792,-760.5221;Inherit;False;False;1;0;FLOAT3;0,0,1;False;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.BreakToComponentsNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;90;-2718.916,1223.29;Inherit;False;FLOAT3;1;0;FLOAT3;0,0,0;False;16;FLOAT;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT;5;FLOAT;6;FLOAT;7;FLOAT;8;FLOAT;9;FLOAT;10;FLOAT;11;FLOAT;12;FLOAT;13;FLOAT;14;FLOAT;15
Node;AmplifyShaderEditor.OneMinusNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;177;-5530.666,-1421.873;Inherit;False;1;0;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.BreakToComponentsNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;178;-5642.666,-1085.876;Inherit;False;FLOAT2;1;0;FLOAT2;0,0;False;16;FLOAT;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT;5;FLOAT;6;FLOAT;7;FLOAT;8;FLOAT;9;FLOAT;10;FLOAT;11;FLOAT;12;FLOAT;13;FLOAT;14;FLOAT;15
Node;AmplifyShaderEditor.FractNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;125;-5693.305,-308.6299;Inherit;False;1;0;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.FWidthOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;159;-5805.305,-20.63049;Inherit;False;1;0;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.OneMinusNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;208;-5563.9,-2668.016;Inherit;False;1;0;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.BreakToComponentsNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;209;-5675.9,-2332.019;Inherit;False;FLOAT2;1;0;FLOAT2;0,0;False;16;FLOAT;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT;5;FLOAT;6;FLOAT;7;FLOAT;8;FLOAT;9;FLOAT;10;FLOAT;11;FLOAT;12;FLOAT;13;FLOAT;14;FLOAT;15
Node;AmplifyShaderEditor.NormalizeNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;227;-2897.661,-758.8678;Inherit;False;False;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleMaxOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;91;-2563.564,1222.284;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMaxOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;180;-5530.666,-1085.876;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMinOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;179;-5338.665,-1581.874;Inherit;False;2;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.OneMinusNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;127;-5517.305,-148.6292;Inherit;False;1;0;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.BreakToComponentsNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;151;-5629.305,187.3677;Inherit;False;FLOAT2;1;0;FLOAT2;0,0;False;16;FLOAT;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT;5;FLOAT;6;FLOAT;7;FLOAT;8;FLOAT;9;FLOAT;10;FLOAT;11;FLOAT;12;FLOAT;13;FLOAT;14;FLOAT;15
Node;AmplifyShaderEditor.SimpleMaxOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;210;-5563.9,-2332.019;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMinOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;212;-5371.9,-2828.017;Inherit;False;2;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.RangedFloatNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;133;-6406.862,-1215.531;Inherit;False;Property;_LineWidthMeters;LineWidthMeters;5;0;Create;True;0;0;0;False;0;False;0.03;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.AbsOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;222;-2713.863,-747.9789;Inherit;False;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.RangedFloatNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;229;-2708.646,-365.7952;Inherit;False;Property;_TriSharp;TriSharp;6;0;Create;True;0;0;0;False;0;False;16;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMaxOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;80;-2521.773,1552.948;Inherit;False;2;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleMaxOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;95;-2320.865,1236.267;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleDivideOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;182;-6170.665,-1245.875;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;183;-5386.665,-1069.877;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0.5;False;1;FLOAT;0
Node;AmplifyShaderEditor.BreakToComponentsNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;184;-5147.17,-1495.182;Inherit;False;FLOAT2;1;0;FLOAT2;0,0;False;16;FLOAT;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT;5;FLOAT;6;FLOAT;7;FLOAT;8;FLOAT;9;FLOAT;10;FLOAT;11;FLOAT;12;FLOAT;13;FLOAT;14;FLOAT;15
Node;AmplifyShaderEditor.SimpleMinOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;126;-5325.305,-308.6299;Inherit;False;2;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleMaxOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;152;-5517.305,187.3677;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleDivideOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;214;-6203.9,-2492.018;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;215;-5419.9,-2316.02;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0.5;False;1;FLOAT;0
Node;AmplifyShaderEditor.BreakToComponentsNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;216;-5180.405,-2741.326;Inherit;False;FLOAT2;1;0;FLOAT2;0,0;False;16;FLOAT;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT;5;FLOAT;6;FLOAT;7;FLOAT;8;FLOAT;9;FLOAT;10;FLOAT;11;FLOAT;12;FLOAT;13;FLOAT;14;FLOAT;15
Node;AmplifyShaderEditor.PowerNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;228;-2503.661,-432.8678;Inherit;False;False;2;0;FLOAT3;0,0,0;False;1;FLOAT;1;False;1;FLOAT3;0
Node;AmplifyShaderEditor.LengthOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;81;-2393.773,1568.948;Inherit;False;1;0;FLOAT3;0,0,0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMinOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;96;-2066.789,1255.578;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMinOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;185;-4959.633,-1437.923;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleSubtractOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;187;-5089.567,-1281.084;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;188;-5070.568,-1166.584;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleDivideOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;146;-6157.305,27.36947;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;153;-5373.305,203.3673;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0.5;False;1;FLOAT;0
Node;AmplifyShaderEditor.BreakToComponentsNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;130;-5133.81,-221.9387;Inherit;False;FLOAT2;1;0;FLOAT2;0,0;False;16;FLOAT;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT;5;FLOAT;6;FLOAT;7;FLOAT;8;FLOAT;9;FLOAT;10;FLOAT;11;FLOAT;12;FLOAT;13;FLOAT;14;FLOAT;15
Node;AmplifyShaderEditor.SimpleMinOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;217;-4992.868,-2684.066;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleSubtractOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;218;-5122.802,-2527.227;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;219;-5103.805,-2412.727;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.DotProductOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;233;-2275.646,-431.7952;Inherit;False;2;0;FLOAT3;0,0,0;False;1;FLOAT3;1,1,1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;99;-1943.944,1534.31;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SmoothstepOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;186;-4759.932,-1307.572;Inherit;False;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMinOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;129;-4946.272,-164.6787;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleSubtractOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;156;-5076.208,-7.83948;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;155;-5057.208,106.6598;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SmoothstepOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;220;-4793.167,-2553.715;Inherit;False;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMaxOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;235;-2093.646,-430.7952;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0.0001;False;1;FLOAT;0
Node;AmplifyShaderEditor.AbsOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;101;-1679.232,1539.409;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;73;-1456.213,1974.279;Inherit;False;Property;_FadeBand;FadeBand;2;0;Create;True;0;0;0;False;0;False;2;2;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;105;-1621.726,1779.8;Inherit;False;Property;_ShowDistance;ShowDistance;3;0;Create;True;0;0;0;False;0;False;2;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.SmoothstepOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;147;-4746.571,-34.32798;Inherit;False;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;244;-4492.998,-2540.768;Inherit;False;LINE XZ;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;246;-4425.48,-1294.416;Inherit;False;LINE YZ;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleDivideOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;238;-1895.046,-495.0953;Inherit;False;2;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleMaxOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;106;-1302.426,1969.306;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0.0001;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleSubtractOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;103;-1417.786,1747.262;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;248;-4480.62,-45.52174;Inherit;False;LINE XY;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.BreakToComponentsNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;240;-1723.449,-491.391;Inherit;False;FLOAT3;1;0;FLOAT3;0,0,0;False;16;FLOAT;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT;5;FLOAT;6;FLOAT;7;FLOAT;8;FLOAT;9;FLOAT;10;FLOAT;11;FLOAT;12;FLOAT;13;FLOAT;14;FLOAT;15
Node;AmplifyShaderEditor.GetLocalVarNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;245;-1529.286,-404.874;Inherit;False;244;LINE XZ;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;247;-1531.089,-630.8217;Inherit;False;246;LINE YZ;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleDivideOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;107;-1158.425,1960.306;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;241;-1312.547,-666.0914;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;242;-1329.864,-463.2949;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;249;-1528.974,-195.0754;Inherit;False;248;LINE XY;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.ClampOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;110;-818.504,1972.619;Inherit;False;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;243;-1306.703,-260.5585;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;250;-980.9742,-595.0753;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SmoothstepOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;111;-611.6821,1965.771;Inherit;False;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;256;-795.9744,-361.0753;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.OneMinusNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;113;-397.7359,1956.014;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.OneMinusNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;258;-591.8828,-353.5571;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.ClampOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;31;-871.6685,465.6384;Inherit;False;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleDivideOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;32;-1029.669,466.6384;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleSubtractOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;33;-1263.669,404.6384;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleSubtractOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;34;-1269.669,528.6385;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.LerpOp, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;28;-611.4335,71.85374;Inherit;False;3;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;2;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.RangedFloatNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;35;-1527.669,526.6385;Inherit;False;Property;_BlueThreshold;Blue Threshold;0;0;Create;True;0;0;0;False;0;False;0.5;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;37;-1527.669,601.6385;Inherit;False;Property;_RedThreshold;Red Threshold;1;0;Create;True;0;0;0;False;0;False;0.3;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.DistanceOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;61;-1519.717,405.9302;Inherit;False;2;0;FLOAT3;0,0,0;False;1;FLOAT4;0,0,0,0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;26;-240.9458,1.19434;Inherit;False;2;2;0;FLOAT;0;False;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;27;-189.7442,511.9346;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.ColorNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;29;-941.6685,-136.3617;Inherit;False;Constant;_Danger;Danger;2;0;Create;True;0;0;0;False;0;False;1,0,0,1;0,0,0,0;True;True;0;6;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT3;5
Node;AmplifyShaderEditor.ColorNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;30;-943.6685,49.63834;Inherit;False;Constant;_Color;Color;2;0;Create;True;0;0;0;False;0;False;0,0.764706,1,1;0,0,0,0;True;True;0;6;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT3;5
Node;AmplifyShaderEditor.TransformPositionNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;39;-1787.939,239.0673;Inherit;False;World;World;False;Fast;True;1;0;FLOAT3;0,0,0;False;5;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.ScreenPosInputsNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;44;-1802.687,432.5405;Float;False;1;False;0;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.CustomExpressionNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;269;-3920,752;Inherit;False;#if defined(UNITY_STEREO_INSTANCING_ENABLED) || defined(UNITY_STEREO_MULTIVIEW_ENABLED)$    return 0.5 * (unity_StereoWorldSpaceCameraPos[0] + unity_StereoWorldSpaceCameraPos[1])@$#else$    return GetCameraPositionWS()@$#endif;3;Create;0;ASE_GetCenterEyeWS;False;False;0;;False;0;1;FLOAT3;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;1;0,0;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;ExtraPrePass;0;0;ExtraPrePass;5;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;5;True;12;all;0;False;True;1;1;False;;0;False;;0;1;False;;0;False;;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;True;True;True;True;0;False;;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;True;1;False;;True;3;False;;True;True;0;False;;0;False;;True;0;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;2;0,0;Float;False;True;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;Chaperone_VR;2992e84f91cbeb14eab234972e07ea9d;True;Forward;0;1;Forward;9;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;2;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Transparent=RenderType;Queue=Transparent=Queue=0;UniversalMaterialType=Unlit;True;5;True;5;d3d11;glcore;gles;gles3;vulkan;0;False;True;1;5;False;;10;False;;1;1;False;;10;False;;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;True;True;True;True;0;False;;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;True;True;2;False;;True;3;False;;True;True;0;False;;0;False;;True;1;LightMode=UniversalForwardOnly;False;False;3;Include;;False;;Native;False;0;0;;Include;Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl;False;;Custom;False;0;0;;Include;Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl ;False;;Custom;False;0;0;;;0;0;Standard;29;Surface;1;638913894373195018;  Blend;0;638914470589785319;Two Sided;0;638913893440871530;Alpha Clipping;1;0;  Use Shadow Threshold;0;0;Forward Only;0;0;Cast Shadows;0;638913890891166213;Receive Shadows;0;638917969334369645;Receive SSAO;1;0;Motion Vectors;0;638917969346624491;  Add Precomputed Velocity;0;0;  XR Motion Vectors;0;0;GPU Instancing;1;0;LOD CrossFade;0;638913890912318552;Built-in Fog;0;638917969392620127;Meta Pass;1;638917969399211893;Extra Pre Pass;0;0;Tessellation;0;0;  Phong;0;0;  Strength;0.5,False,;0;  Type;0;0;  Tess;16,False,;0;  Min;10,False,;0;  Max;25,False,;0;  Edge Length;16,False,;0;  Max Displacement;25,False,;0;Write Depth;0;638917969437728140;  Early Z;0;0;Vertex Position,InvertActionOnDeselection;1;0;0;13;False;True;False;True;True;False;True;True;True;False;False;False;True;False;;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;3;0,0;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;ShadowCaster;0;2;ShadowCaster;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;5;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;False;False;True;False;False;False;False;0;False;;False;False;False;False;False;False;False;False;False;True;1;False;;True;3;False;;False;True;1;LightMode=ShadowCaster;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;4;0,0;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;DepthOnly;0;3;DepthOnly;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;5;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;False;False;True;True;False;False;False;0;False;;False;False;False;False;False;False;False;False;False;True;1;False;;False;False;True;1;LightMode=DepthOnly;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;5;0,0;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;Meta;0;4;Meta;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;5;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;2;False;;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=Meta;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;6;0,0;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;Universal2D;0;5;Universal2D;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;5;True;12;all;0;False;True;1;1;False;;0;False;;0;1;False;;0;False;;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;True;True;True;True;0;False;;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;True;1;False;;True;3;False;;True;True;0;False;;0;False;;True;1;LightMode=Universal2D;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;7;0,0;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;SceneSelectionPass;0;6;SceneSelectionPass;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;5;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;2;False;;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=SceneSelectionPass;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;8;0,0;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;ScenePickingPass;0;7;ScenePickingPass;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;5;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=Picking;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;9;0,0;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;DepthNormals;0;8;DepthNormals;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;5;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;False;;True;3;False;;False;True;1;LightMode=DepthNormalsOnly;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;10;0,0;Float;False;False;-1;2;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;DepthNormalsOnly;0;9;DepthNormalsOnly;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;5;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;False;;True;3;False;;False;True;1;LightMode=DepthNormalsOnly;False;True;9;d3d11;metal;vulkan;xboxone;xboxseries;playstation;ps4;ps5;switch;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;259;0,100;Float;False;False;-1;3;UnityEditor.ShaderGraphUnlitGUI;0;13;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;MotionVectors;0;10;MotionVectors;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;5;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;True;True;False;False;0;False;;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=MotionVectors;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;270;0,110;Float;False;False;-1;3;UnityEditor.ShaderGraphUnlitGUI;0;1;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;XRMotionVectors;0;11;XRMotionVectors;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;5;True;12;all;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;True;True;True;True;0;False;;False;False;False;False;False;False;False;True;True;1;False;;255;False;;1;False;;7;False;;3;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;1;LightMode=XRMotionVectors;False;False;0;;0;0;Standard;0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode, AmplifyShaderEditor, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null;271;0,110;Float;False;False;-1;3;UnityEditor.ShaderGraphUnlitGUI;0;1;New Amplify Shader;2992e84f91cbeb14eab234972e07ea9d;True;GBuffer;0;12;GBuffer;0;False;False;False;False;False;False;False;False;False;False;False;False;True;0;False;;False;True;0;False;;False;False;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;False;False;False;True;4;RenderPipeline=UniversalPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;UniversalMaterialType=Unlit;True;5;True;12;all;0;False;True;1;5;False;;10;False;;1;1;False;;10;False;;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;True;True;True;True;0;False;;False;False;False;False;False;False;False;True;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;True;2;False;;True;3;False;;True;True;0;False;;0;False;;True;1;LightMode=UniversalGBuffer;False;False;0;;0;0;Standard;0;False;0
WireConnection;76;0;269;0
WireConnection;77;0;76;0
WireConnection;77;1;71;0
WireConnection;78;0;77;0
WireConnection;191;0;120;0
WireConnection;189;0;173;0
WireConnection;198;0;120;0
WireConnection;199;0;195;0
WireConnection;79;0;78;0
WireConnection;79;1;72;0
WireConnection;174;0;189;0
WireConnection;174;1;191;0
WireConnection;137;0;120;0
WireConnection;134;0;119;0
WireConnection;202;0;199;0
WireConnection;202;1;198;0
WireConnection;124;0;79;0
WireConnection;124;1;123;0
WireConnection;175;0;174;0
WireConnection;176;0;174;0
WireConnection;121;0;134;0
WireConnection;121;1;137;0
WireConnection;204;0;202;0
WireConnection;205;0;202;0
WireConnection;90;0;124;0
WireConnection;177;0;175;0
WireConnection;178;0;176;0
WireConnection;125;0;121;0
WireConnection;159;0;121;0
WireConnection;208;0;204;0
WireConnection;209;0;205;0
WireConnection;227;0;221;0
WireConnection;91;0;90;0
WireConnection;91;1;90;1
WireConnection;180;0;178;0
WireConnection;180;1;178;1
WireConnection;179;0;175;0
WireConnection;179;1;177;0
WireConnection;127;0;125;0
WireConnection;151;0;159;0
WireConnection;210;0;209;0
WireConnection;210;1;209;1
WireConnection;212;0;204;0
WireConnection;212;1;208;0
WireConnection;222;0;227;0
WireConnection;80;0;124;0
WireConnection;95;0;91;0
WireConnection;95;1;90;2
WireConnection;182;0;133;0
WireConnection;182;1;191;0
WireConnection;183;0;180;0
WireConnection;184;0;179;0
WireConnection;126;0;125;0
WireConnection;126;1;127;0
WireConnection;152;0;151;0
WireConnection;152;1;151;1
WireConnection;214;0;133;0
WireConnection;214;1;198;0
WireConnection;215;0;210;0
WireConnection;216;0;212;0
WireConnection;228;0;222;0
WireConnection;228;1;229;0
WireConnection;81;0;80;0
WireConnection;96;0;95;0
WireConnection;185;0;184;0
WireConnection;185;1;184;1
WireConnection;187;0;182;0
WireConnection;187;1;183;0
WireConnection;188;0;182;0
WireConnection;188;1;183;0
WireConnection;146;0;133;0
WireConnection;146;1;137;0
WireConnection;153;0;152;0
WireConnection;130;0;126;0
WireConnection;217;0;216;0
WireConnection;217;1;216;1
WireConnection;218;0;214;0
WireConnection;218;1;215;0
WireConnection;219;0;214;0
WireConnection;219;1;215;0
WireConnection;233;0;228;0
WireConnection;99;0;96;0
WireConnection;99;1;81;0
WireConnection;186;0;185;0
WireConnection;186;1;187;0
WireConnection;186;2;188;0
WireConnection;129;0;130;0
WireConnection;129;1;130;1
WireConnection;156;0;146;0
WireConnection;156;1;153;0
WireConnection;155;0;146;0
WireConnection;155;1;153;0
WireConnection;220;0;217;0
WireConnection;220;1;218;0
WireConnection;220;2;219;0
WireConnection;235;0;233;0
WireConnection;101;0;99;0
WireConnection;147;0;129;0
WireConnection;147;1;156;0
WireConnection;147;2;155;0
WireConnection;244;0;220;0
WireConnection;246;0;186;0
WireConnection;238;0;228;0
WireConnection;238;1;235;0
WireConnection;106;0;73;0
WireConnection;103;0;101;0
WireConnection;103;1;105;0
WireConnection;248;0;147;0
WireConnection;240;0;238;0
WireConnection;107;0;103;0
WireConnection;107;1;106;0
WireConnection;241;0;240;0
WireConnection;241;1;247;0
WireConnection;242;0;240;1
WireConnection;242;1;245;0
WireConnection;110;0;107;0
WireConnection;243;0;240;2
WireConnection;243;1;249;0
WireConnection;250;0;241;0
WireConnection;250;1;242;0
WireConnection;111;0;110;0
WireConnection;256;0;250;0
WireConnection;256;1;243;0
WireConnection;113;0;111;0
WireConnection;258;0;256;0
WireConnection;31;0;32;0
WireConnection;32;0;33;0
WireConnection;32;1;34;0
WireConnection;33;0;61;0
WireConnection;33;1;37;0
WireConnection;34;0;35;0
WireConnection;34;1;37;0
WireConnection;28;0;29;0
WireConnection;28;1;30;0
WireConnection;28;2;31;0
WireConnection;61;0;39;0
WireConnection;61;1;44;0
WireConnection;26;0;258;0
WireConnection;26;1;28;0
WireConnection;27;0;258;0
WireConnection;27;1;113;0
WireConnection;2;2;26;0
WireConnection;2;3;27;0
ASEEND*/
//CHKSM=16F3AD558F09938F7530EF8874FAE52062F153EA