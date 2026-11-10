// Unlit sprite with an HDR tint and a white hit flash (Godot hit_flash.gdshader + modulate above 1).
// _Tint and _FlashAmount are set per renderer through MaterialPropertyBlock or animated by an Animator
// (bind "material._Tint" / "material._FlashAmount" on the SpriteRenderer).
Shader "RetroSF/Sprite"
{
    Properties
    {
        [PerRendererData] _MainTex ("Sprite Texture", 2D) = "white" {}
        [HDR] _Tint ("Tint", Color) = (1, 1, 1, 1)
        _FlashAmount ("Flash Amount", Range(0, 1)) = 0
        [HideInInspector] _RendererColor ("RendererColor", Color) = (1, 1, 1, 1)
        [HideInInspector] _Flip ("Flip", Vector) = (1, 1, 1, 1)
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "IgnoreProjector" = "True"
            "PreviewType" = "Plane"
            "CanUseSpriteAtlas" = "True"
        }

        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off
        ZWrite Off

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        struct Attributes
        {
            float3 positionOS : POSITION;
            float4 color : COLOR;
            float2 uv : TEXCOORD0;
        };

        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            half4 color : COLOR;
            float2 uv : TEXCOORD0;
        };

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        CBUFFER_START(UnityPerMaterial)
            half4 _Tint;
            half _FlashAmount;
        CBUFFER_END

        half4 _RendererColor;

        Varyings Vert(Attributes input)
        {
            Varyings output;
            output.positionCS = TransformObjectToHClip(input.positionOS);
            output.uv = input.uv;
            output.color = input.color * _RendererColor;
            return output;
        }

        half4 Frag(Varyings input) : SV_Target
        {
            half4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv) * input.color * _Tint;
            // Replace the body's color while preserving texture and vertex alpha.
            color.rgb = lerp(color.rgb, half3(1, 1, 1), _FlashAmount);
            return color;
        }
        ENDHLSL

        Pass
        {
            Tags { "LightMode" = "Universal2D" }
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            ENDHLSL
        }

        Pass
        {
            Tags { "LightMode" = "UniversalForward" }
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            ENDHLSL
        }
    }
}
