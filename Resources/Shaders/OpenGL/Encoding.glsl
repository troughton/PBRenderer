//http://aras-p.info/texts/CompactNormalStorage.html

/** n must be a vector within 90 degrees in x and y of z = 1. Uses stereographic projection.*/
vec2 encodeStereographic (vec3 n) {
    vec2 enc = n.xy / (n.z + 1);
    return enc * 0.5 + 0.5;
}

//all of these are are transposes of the TBN matrix.
const mat3 positiveXBasis = mat3(0, 0, 1,
                                 1, 0, 0,
                                 0, 1, 0);
const mat3 positiveYBasis = mat3(1, 0, 0,
                                 0, 0, 1,
                                 0, 1, 0);
const mat3 positiveZBasis = mat3(1, 0, 0,
                                 0, 1, 0,
                                 0, 0, 1);
const mat3 negativeXBasis = mat3(0, 0, -1,
                                 1, 0, 0,
                                 0, 1, 0);
const mat3 negativeYBasis = mat3(1, 0, 0,
                                 0, 0, -1,
                                 0, 1, 0);
const mat3 negativeZBasis = mat3(1, 0, 0,
                                 0, 1, 0,
                                 0, 0, -1);

#define BasisIndexPositiveX 0
#define BasisIndexPositiveY 1
#define BasisIndexPositiveZ 2
#define BasisIndexNegativeX 3
#define BasisIndexNegativeY 4
#define BasisIndexNegativeZ 5

vec2 encode (vec3 n, out int basis) {
    
    vec3 nAbs = abs(n);
    
    vec3 transformedN;
    if (nAbs.x >= nAbs.y && nAbs.x >= nAbs.z) {
        //normal points at +x or -x
        if (n.x > 0) {
            //Positive X
            basis = BasisIndexPositiveX;
            transformedN = positiveXBasis * n;
        } else {
            basis = BasisIndexNegativeX;
            //Negative X
            transformedN = negativeXBasis * n;
        }
    } else if (nAbs.y >= nAbs.x && nAbs.y >= nAbs.z) {
        //normal points at +y or -y
        if (n.y > 0) {
            basis = BasisIndexPositiveY;
            transformedN = positiveYBasis * n;
        } else {
            basis = BasisIndexNegativeY;
            transformedN = negativeYBasis * n;
        }
    } else {
        //normal points at +z or -z
        if (n.z > 0) {
            basis = BasisIndexPositiveZ;
            transformedN = positiveZBasis * n;
        } else {
            basis = BasisIndexNegativeZ;
            transformedN = negativeZBasis * n;
        }
    }
    
    return encodeStereographic(transformedN);
}

vec3 decodeStereographic(vec2 enc) {
    vec3 nn =
    vec3(enc, 0) * (float3)(2.f, 2.f, 0.f) +
    vec3(-1.f, -1.f, 1.f);
    float g = 2.0f / dot(nn, nn);
    vec3 n;
    n.xy = g*nn.xy;
    n.z = g - 1;
    return n;
}

#define BasisIndexPositiveX 0
#define BasisIndexPositiveY 1
#define BasisIndexPositiveZ 2
#define BasisIndexNegativeX 3
#define BasisIndexNegativeY 4
#define BasisIndexNegativeZ 5

vec3 decode(vec2 enc, float basis) {
    vec3 normal = decodeStereographic(enc);
    //The normal will be within 90 degrees in x and y of (0, 0, 1)
    
    vec3 output;
    
    if (basis < BasisIndexPositiveX + 0.5f) {
        output = normal.zxy;
    } else if (basis < BasisIndexPositiveY + 0.5f) {
        output = normal.xzy;
    } else if (basis < BasisIndexPositiveZ + 0.5f) {
        output = normal;
    } else if (basis < BasisIndexNegativeX + 0.5f) {
        output = normal.zxy;
        output.x *= -1;
    } else if (basis < BasisIndexNegativeY + 0.5f) {
        output = normal.xzy;
        output.y *= -1;
    } else {
        output = normal;
        output.z *= -1;
    }
    return output;
}


#include "MaterialData.glsl"

void encodeDataToGBuffers(in MaterialData data, in vec3 normal, inout uint gBuffer0, inout vec4 gBuffer1, inout vec4 gBuffer2) {
    int basisIndex;
    vec2 encodedNormal = encode(normal, basisIndex);
    uint nX = uint(encodedNormal.x * 1023.f);
    uint nY = uint(encodedNormal.y * 1023.f);
    uint smoothness = uint(data.smoothness * 1023.f);
    
    gBuffer0 = (nX << 22) | (nY << 12) | (smoothness << 2);
    
    gBuffer1.rgb = data.baseColour.rgb;
    gBuffer1.a = basisIndex / 8.0;
    gBuffer2.g = data.metalMask;
    gBuffer2.b = data.reflectance;
}

MaterialData decodeDataFromGBuffers(out vec3 N, uint gBuffer0, vec4 gBuffer1, vec4 gBuffer2) {
    const float divideFactor = 0.0009775171065f; // 1 / 1023
    
    uint nX = (gBuffer0 >> 22) & 0b1111111111;
    uint nY = (gBuffer0 >> 12) & 0b1111111111;
    uint smoothness = (gBuffer0 >> 2) & 0b1111111111;
    
    float basisIndex = gBuffer1.a * 8.0;
    vec2 encodedNormal = vec2(nX * divideFactor, nY * divideFactor);
    N = decode(encodedNormal, basisIndex);
    
    
    MaterialData data;
    data.smoothness = (float)(smoothness * divideFactor);
    data.baseColour = gBuffer1.xyz;
    data.metalMask = gBuffer2.y;
    data.reflectance = gBuffer2.z;
    
    return data;
}