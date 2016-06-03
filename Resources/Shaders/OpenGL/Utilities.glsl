float saturate(float value) {
    return clamp(value, 0, 1);
}

float sqr(float value) {
    return value * value;
}

const float PI = 3.141592653589793f;
const float INV_PI = 0.3183098862f;
const float HALF_PI = 1.570796f;

vec2 angularProbeDirectionToUV(vec3 angularProbeDirection) {
    float r = 1.f/PI * acos(angularProbeDirection.z)/length(angularProbeDirection);
    return vec2(angularProbeDirection.x * r, angularProbeDirection.y * r);
}

//https://seblagarde.wordpress.com/2014/12/01/inverse-trigonometric-functions-gpu-optimization-for-amd-gcn-architecture/

float fast_acos(float inX) {
    float x = abs(inX);
    float res = -0.156583f * x + HALF_PI;
    res *= sqrt(1.0f - x);
    return (inX >= 0) ? res : PI - res;
}

// Same cost as Acos + 1 FR
// Same error
// input [-1, 1] and output [-PI/2, PI/2]
float fast_asin(float x)
{
    return HALF_PI - fast_acos(x);
}

// max absolute error 1.3x10^-3
// Eberly's odd polynomial degree 5 - respect bounds
// 4 VGPR, 14 FR (10 FR, 1 QR), 2 scalar
// input [0, infinity] and output [0, PI/2]
float fast_atan_pos(float x)
{
    float t0 = (x < 1.0f) ? x : 1.0f / x;
    float t1 = t0 * t0;
    float poly = 0.0872929f;
    poly = -0.301895f + poly * t1;
    poly = 1.0f + poly * t1;
    poly = poly * t0;
    return (x < 1.0f) ? poly : HALF_PI - poly;
}

// 4 VGPR, 16 FR (12 FR, 1 QR), 2 scalar
// input [-infinity, infinity] and output [-PI/2, PI/2]
float fast_atan(float x) {
    float t0 = fast_atan_pos(abs(x));
    return (x < 0.0f) ? -t0: t0;
}

float lineariseDepth(float depth, float near, float far) {
    float z = (2 * near) / (far + near - depth * (far - near));
    return z;
}