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

MaterialData decodeMaterialFromGBuffers(vec4 gBuffer0, vec4 gBuffer1, vec4 gBuffer2) {
    MaterialData data;
    data.smoothness = gBuffer0.b;
    data.baseColour = vec4(gBuffer1.rgb, 1);
    data.metalMask = gBuffer2.g;
    data.reflectance = gBuffer2.b;
    
    return data;
}