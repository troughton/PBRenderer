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
#define HALF_PI 1.570796f

//https://seblagarde.wordpress.com/2014/12/01/inverse-trigonometric-functions-gpu-optimization-for-amd-gcn-architecture/

float fast_acos(float inX);
float fast_acos(float inX)
{
    float x = fabs(inX);
    float res = -0.156583f * x + HALF_PI;
    res *= sqrt(1.0f - x);
    return (inX >= 0) ? res : PI - res;
}

// Same cost as Acos + 1 FR
// Same error
// input [-1, 1] and output [-PI/2, PI/2]
float fast_asin(float x);
float fast_asin(float x)
{
    return HALF_PI - fast_acos(x);
}

// max absolute error 1.3x10^-3
// Eberly's odd polynomial degree 5 - respect bounds
// 4 VGPR, 14 FR (10 FR, 1 QR), 2 scalar
// input [0, infinity] and output [0, PI/2]
float fast_atan_pos(float x);
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
float fast_atan(float x);
float fast_atan(float x)
{
    float t0 = fast_atan_pos(fabs(x));
    return (x < 0.0f) ? -t0: t0;
}