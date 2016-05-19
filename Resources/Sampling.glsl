#include "Utilities.glsl"

//http://holger.dammertz.org/stuff/notes_HammersleyOnHemisphere.html
float radicalInverse_VdC(uint bits) {
    bits = (bits << 16u) | (bits >> 16u);
    bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
    bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
    bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
    bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
    return float(bits) * 2.3283064365386963e-10; // / 0x100000000
}

//http://holger.dammertz.org/stuff/notes_HammersleyOnHemisphere.html
vec2 getSample(uint i, uint N) {
    return vec2(float(i)/float(N), radicalInverse_VdC(i));
}


void importanceSampleCosDir(vec2 u, vec3 N, out vec3 L, out float NdotL, out float pdf) {
    // Local referencial
    vec3 upVector = abs(N.z) < 0.999 ? vec3(0,0,1) : vec3(1,0,0);
    vec3 tangentX = normalize( cross( upVector, N ) );
    vec3 tangentY = cross( N, tangentX );
    float u1 = u.x;
    float u2 = u.y;
    
    float r = sqrt(u1);
    float phi = u2 * PI * 2;
    
    L = vec3(r*cos(phi), r*sin(phi), sqrt(max(0.0f, 1.0f-u1)));
    L = normalize(tangentX * L.y + tangentY * L.x + N * L.z);
    
    NdotL = dot(L, N);
    pdf = NdotL * INV_PI;
}

//http://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_notes_v2.pdf

vec3 ImportanceSampleGGX(vec2 Xi, float roughness, vec3 N) {
    float a = roughness * roughness;
    float Phi = 2 * PI * Xi.x;
    float CosTheta = sqrt( (1 - Xi.y) / ( 1 + (a*a - 1) * Xi.y ) );
    float SinTheta = sqrt( 1 - CosTheta * CosTheta );
    vec3 H;
    H.x = SinTheta * cos( Phi );
    H.y = SinTheta * sin( Phi );
    H.z = CosTheta;
    vec3 UpVector = abs(N.z) < 0.999 ? vec3(0,0,1) : vec3(1,0,0);
    vec3 TangentX = normalize( cross( UpVector , N ) );
    vec3 TangentY = cross( N, TangentX );
    // Tangent to world space
    return TangentX * H.x + TangentY * H.y + N * H.z;
}
