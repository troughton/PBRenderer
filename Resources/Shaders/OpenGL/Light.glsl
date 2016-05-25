const uint LightTypePoint = 0;
const uint LightTypeDirectional = 1;
const uint LightTypeSpot = 2;

struct LightData {
    mat4 lightToWorld;
    vec4 colourAndIntensity;
    uint lightTypeFlag;
    float inverseSquareAttenuationRadius;
};
