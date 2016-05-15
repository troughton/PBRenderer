struct MaterialData {
    vec3 baseColour;
    float smoothness;
    float metalMask;
    float reflectance;
};

float saturate(float value) {
    return clamp(value, 0, 1);
}

void evaluateMaterialData(in MaterialData data, out vec3 albedo, out vec3 f0, out float f90, out float linearRoughness) {
    vec3 diffuseF0 = vec3(0.16 + data.reflectance * data.reflectance);
    albedo = mix(data.baseColour, vec3(0), data.metalMask);
    f0 = mix(diffuseF0, data.baseColour, data.metalMask);
    f90 = saturate(50.0 * dot(f0, vec3(0.33)));
    linearRoughness = 1 - data.smoothness;
}