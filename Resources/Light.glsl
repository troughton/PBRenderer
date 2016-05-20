const uint LightTypePoint = 0;
const uint LightTypeDirectional = 1;
const uint LightTypeSpot = 2;

struct LightData {
    vec4 colourAndIntensity;
    mat4 lightToWorld;
    uint lightTypeFlag;
    float inverseSquareAttenuationRadius;
};
