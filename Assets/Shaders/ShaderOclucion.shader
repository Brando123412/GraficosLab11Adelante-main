Shader "Custom/ShaderOclucion"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _NormalMap("NormalMap", 2D) = "white" {}
        _LightColor("LightColor", Color) = (1,1,1,1)

        _AO("AO (RGB)", 2D) = "white" {}
        _ScalarAO("ScalarAO", Range(0,1)) = 0.5
    }
    SubShader
    {
        Pass{
        Tags{ "RenderType" = "Opaque" }
        LOD 200
        CGPROGRAM
        #include "UnityCG.cginc"
        #pragma vertex vs_main
        #pragma fragment fs_main
        struct VS_IN
        {
            float4 position : POSITION;
            float3 normal : NORMAL;
            float3 tangent : TANGENT;
            // float3 binormal : BINORMAL; // unity does not support BINORMAL semantic?
            float2 uv : TEXCOORD0;
        };
        struct VS_OUT
        {
            float4 position : POSITION;
            float2 uv : TEXCOORD0;
            float3 lightdir : TEXCOORD1;
            float3 viewdir : TEXCOORD2;
            float3 T : TEXCOORD3;
            float3 B : TEXCOORD4;
            float3 N : TEXCOORD5;
        // TANGENT, BINORMAL, NORMAL semantics are only available for input of vertex shader
        };
        uniform float4 _Color;
        uniform float4 _LightColor;

        uniform sampler _MainTex;
        uniform sampler _NormalMap;

        uniform sampler _AO;
        uniform float _ScalarAO;

        VS_OUT vs_main(VS_IN input)
        {
            VS_OUT output;
            // calc output position directly
            output.position = UnityObjectToClipPos(input.position);
            //
            // pass uv coord
            output.uv = input.uv;
            // calc lightDir vector heading current vertex
            float4 worldPosition = mul(unity_ObjectToWorld, input.position);
            float3 lightDir = worldPosition.xyz - _WorldSpaceLightPos0.xyz;
            output.lightdir = normalize(lightDir);
            // calc viewDir vector 
            float3 viewDir = normalize(worldPosition.xyz - _WorldSpaceCameraPos.xyz);
            output.viewdir = viewDir;
            // calc Normal, Binormal, Tangent vector in world space
            // cast 1st arg to 'float3x3' (type of input.normal is 'float3')
            float3 worldNormal = mul((float3x3)unity_ObjectToWorld, input.normal);
            float3 worldTangent = mul((float3x3)unity_ObjectToWorld, input.tangent);
            float3 binormal = cross(input.normal, input.tangent.xyz); // *input.tangent.w;
            float3 worldBinormal = mul((float3x3)unity_ObjectToWorld, binormal);
            // and, set them
            output.N = normalize(worldNormal);
            output.T = normalize(worldTangent);
            output.B = normalize(worldBinormal);
            return output;
        }
        float4 fs_main(VS_OUT input) : COLOR
        {
            // obtain a normal vector on tangent space
            float3 tangentNormal = tex2D(_NormalMap, input.uv).xyz;
            //
            float3 AO = tex2D(_AO, input.uv).rgb * _ScalarAO;
            // and change range of values (0 ~ 1)
            tangentNormal = normalize(tangentNormal * 2 - 1);
            // 'TBN' transforms the world space into a tangent space
            // we need its inverse matrix
            // Tip : An inverse matrix of orthogonal matrix is its transpose matrix
            float3x3 TBN = float3x3(normalize(input.T), normalize(input.B), normalize(input.N));
            TBN = transpose(TBN);
            // finally we got a normal vector from the normal map
            float3 worldNormal = mul(TBN, tangentNormal);
            // Lambert here (cuz we're calculating Normal vector in this pixel shader)
            float4 albedo = tex2D(_MainTex, input.uv);
            float3 lightDir = normalize(input.lightdir);
            // calc diffuse, as we did in pixel shader
            float3 diffuse = saturate(dot(worldNormal, -lightDir));
            diffuse = _LightColor * albedo.rgb * diffuse;
            // Specular here
            float3 specular = 0;
            if (diffuse.x > 0) {
                float3 reflection = reflect(lightDir, worldNormal);
                float3 viewDir = normalize(input.viewdir);
                specular = saturate(dot(reflection, -viewDir));
                specular = pow(specular, 20.0f);
            }
            // make some ambient,
            float3 ambient = float3(0.1f, 0.1f, 0.1f) * 3 * albedo;
            // combine all of colors
            float4 col = float4((ambient + diffuse + specular) *AO.rgb, 1);
            return float4(col.rgb , 1)*_Color;
        }
        ENDCG
        }
    }
    FallBack "Diffuse"
}
