float saturate(float value) {
    return clamp(value, 0, 1);
}

float sqr(float value) {
    return value * value;
}

vec3 pow(vec3 value, float exponent) {
    return pow(value, vec3(exponent));
}

const float PI = 3.141592653589793;
const float INV_PI = 0.3183098862;

vec2 angularProbeDirectionToUV(vec3 angularProbeDirection) {
    float r = 1.f/PI * acos(angularProbeDirection.z)/length(angularProbeDirection);
    return vec2(angularProbeDirection.x * r, angularProbeDirection.y * r);
}