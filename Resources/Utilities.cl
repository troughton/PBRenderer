float3 native_normalize(float3 vector);
float3 native_normalize(float3 vector) {
    return vector * native_rsqrt(dot(vector, vector));
}

float saturate(float value);
float saturate(float value) {
    return clamp(value, 0.f, 1.f);
}

float sqr(float value);
float sqr(float value) {
    return value * value;
}

#define PI 3.141592653589793f
#define INV_PI 0.3183098862f