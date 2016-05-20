float saturate(float value) {
    return clamp(value, 0.f, 1.f);
}

float sqr(float value) {
    return value * value;
}

__constant const float PI = 3.141592653589793;
__constant const float INV_PI = 0.3183098862;